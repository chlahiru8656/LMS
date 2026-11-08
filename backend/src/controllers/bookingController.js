const pool = require('../config/db');

// ============================================================
// CREATE BOOKING REQUEST (Course Coordinator)
// ============================================================
const createBookingRequest = async (req, res) => {
  try {
    const { practical_id, instructor_id, booking_date, start_time, end_time, group_name } = req.body;

    if (!practical_id || !instructor_id || !booking_date || !start_time || !end_time) {
      return res.status(400).json({ message: 'Practical, instructor, date, start time and end time are required.' });
    }

    // Check for time slot conflicts
    const [conflicts] = await pool.query(
      `SELECT id FROM booking_requests 
       WHERE lab_id = 1 
       AND booking_date = ? 
       AND status IN ('pending', 'to_reviewed', 'approved')
       AND ((start_time < ? AND end_time > ?) OR (start_time < ? AND end_time > ?) OR (start_time >= ? AND end_time <= ?))`,
      [booking_date, end_time, start_time, end_time, start_time, start_time, end_time]
    );

    if (conflicts.length > 0) {
      return res.status(409).json({ message: 'This time slot conflicts with an existing booking.' });
    }

    // Check for cleaning schedule conflicts
    const [cleaningConflicts] = await pool.query(
      `SELECT cs.id FROM cleaning_schedules cs
       JOIN cleaning_logs cl ON cs.id = cl.schedule_id
       WHERE cs.lab_id = 1
       AND cl.scheduled_date = ?
       AND cl.status = 'pending'
       AND cs.scheduled_time IS NOT NULL`,
      [booking_date]
    );

    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();

      // Create the booking request
      const [result] = await connection.query(
        `INSERT INTO booking_requests (practical_id, requested_by, instructor_id, lab_id, booking_date, start_time, end_time, group_name, status)
         VALUES (?, ?, ?, 1, ?, ?, ?, ?, 'pending')`,
        [practical_id, req.user.id, instructor_id, booking_date, start_time, end_time, group_name || null]
      );
      const bookingId = result.insertId;

      // Auto-populate students from course enrollment
      const [practical] = await connection.query('SELECT course_id FROM practicals WHERE id = ?', [practical_id]);
      if (practical.length > 0) {
        const courseId = practical[0].course_id;
        const [enrollments] = await connection.query(
          'SELECT student_id FROM course_enrollments WHERE course_id = ?',
          [courseId]
        );

        if (enrollments.length > 0) {
          const studentValues = enrollments.map(e => [bookingId, e.student_id]);
          await connection.query(
            'INSERT INTO booking_students (booking_request_id, student_id) VALUES ?',
            [studentValues]
          );
        }
      }

      await connection.commit();
      res.status(201).json({ message: 'Booking request submitted successfully.', id: bookingId });
    } catch (err) {
      await connection.rollback();
      throw err;
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error('Create booking error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// GET BOOKING REQUESTS
// ============================================================
const getAllBookingRequests = async (req, res) => {
  try {
    const { status, date } = req.query;
    let query = `
      SELECT br.*, 
             p.name as practical_name,
             c.code as course_code, c.name as course_name,
             u1.name as requested_by_name,
             u2.name as instructor_name,
             (SELECT COUNT(*) FROM booking_students bs WHERE bs.booking_request_id = br.id) as student_count,
             (SELECT COUNT(*) FROM booking_comments bc WHERE bc.booking_request_id = br.id) as comment_count
      FROM booking_requests br
      JOIN practicals p ON br.practical_id = p.id
      JOIN courses c ON p.course_id = c.id
      JOIN users u1 ON br.requested_by = u1.id
      JOIN users u2 ON br.instructor_id = u2.id
      WHERE 1=1
    `;
    const params = [];

    if (status) {
      query += ' AND br.status = ?';
      params.push(status);
    }
    if (date) {
      query += ' AND br.booking_date = ?';
      params.push(date);
    }

    query += ' ORDER BY br.booking_date DESC, br.start_time ASC';

    const [requests] = await pool.query(query, params);
    res.json(requests);
  } catch (error) {
    console.error('Get booking requests error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// Get a single booking request with full details
const getBookingRequestById = async (req, res) => {
  try {
    const { id } = req.params;

    const [requests] = await pool.query(
      `SELECT br.*, 
              p.name as practical_name, p.description as practical_description, p.lab_sheet_url,
              c.code as course_code, c.name as course_name,
              s.name as semester_name,
              b.name as batch_name,
              u1.name as requested_by_name, u1.email as requested_by_email,
              u2.name as instructor_name, u2.email as instructor_email
       FROM booking_requests br
       JOIN practicals p ON br.practical_id = p.id
       JOIN courses c ON p.course_id = c.id
       JOIN semesters s ON c.semester_id = s.id
       JOIN batches b ON s.batch_id = b.id
       JOIN users u1 ON br.requested_by = u1.id
       JOIN users u2 ON br.instructor_id = u2.id
       WHERE br.id = ?`,
      [id]
    );

    if (requests.length === 0) {
      return res.status(404).json({ message: 'Booking request not found.' });
    }

    const request = requests[0];

    // Get students
    const [students] = await pool.query(
      `SELECT bs.*, u.name as student_name, u.student_staff_id, u.email
       FROM booking_students bs
       JOIN users u ON bs.student_id = u.id
       WHERE bs.booking_request_id = ?
       ORDER BY u.name`,
      [id]
    );

    // Get comments
    const [comments] = await pool.query(
      `SELECT bc.*, u.name as commenter_name, u.role as commenter_role
       FROM booking_comments bc
       JOIN users u ON bc.commented_by = u.id
       WHERE bc.booking_request_id = ?
       ORDER BY bc.created_at ASC`,
      [id]
    );

    // Get required equipment
    const [equipment] = await pool.query(
      `SELECT pe.*, e.name as equipment_name, e.model, e.status as equipment_status
       FROM practical_equipment pe
       JOIN equipment e ON pe.equipment_id = e.id
       WHERE pe.practical_id = ?`,
      [request.practical_id]
    );

    // Get required materials
    const [materials] = await pool.query(
      `SELECT pm.*, c.name as consumable_name, c.unit, c.current_stock
       FROM practical_materials pm
       JOIN consumables c ON pm.consumable_id = c.id
       WHERE pm.practical_id = ?`,
      [request.practical_id]
    );

    res.json({ ...request, students, comments, equipment, materials });
  } catch (error) {
    console.error('Get booking request error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// GET LAB AVAILABILITY (for all users including students)
// Privacy: only shows Available/Booked status
// ============================================================
const getLabAvailability = async (req, res) => {
  try {
    const { date } = req.query;
    if (!date) {
      return res.status(400).json({ message: 'Date is required.' });
    }

    const [bookings] = await pool.query(
      `SELECT booking_date, start_time, end_time, status
       FROM booking_requests
       WHERE lab_id = 1 AND booking_date = ? AND status IN ('approved', 'pending', 'to_reviewed')`,
      [date]
    );

    // Return only time slots and their status (no details, no names — privacy)
    const slots = bookings.map(b => ({
      date: b.booking_date,
      start_time: b.start_time,
      end_time: b.end_time,
      status: 'booked'
    }));

    res.json(slots);
  } catch (error) {
    console.error('Get availability error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// ADD COMMENT (Lab TO / Lab Assistant)
// ============================================================
const addComment = async (req, res) => {
  try {
    const { id } = req.params; // booking request id
    const { comment } = req.body;

    if (!comment) {
      return res.status(400).json({ message: 'Comment is required.' });
    }

    // Verify booking exists
    const [booking] = await pool.query('SELECT id, status FROM booking_requests WHERE id = ?', [id]);
    if (booking.length === 0) {
      return res.status(404).json({ message: 'Booking request not found.' });
    }

    await pool.query(
      'INSERT INTO booking_comments (booking_request_id, commented_by, comment) VALUES (?, ?, ?)',
      [id, req.user.id, comment]
    );

    // Update status to 'to_reviewed' if it was 'pending'
    if (booking[0].status === 'pending') {
      await pool.query(
        "UPDATE booking_requests SET status = 'to_reviewed' WHERE id = ?",
        [id]
      );
    }

    res.status(201).json({ message: 'Comment added successfully.' });
  } catch (error) {
    console.error('Add comment error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// APPROVE / REJECT (Lab Incharge)
// ============================================================
const updateBookingStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status, incharge_remarks } = req.body;

    if (!['approved', 'rejected', 'cancelled'].includes(status)) {
      return res.status(400).json({ message: 'Status must be approved, rejected or cancelled.' });
    }

    const [booking] = await pool.query('SELECT id, status FROM booking_requests WHERE id = ?', [id]);
    if (booking.length === 0) {
      return res.status(404).json({ message: 'Booking request not found.' });
    }

    await pool.query(
      'UPDATE booking_requests SET status = ?, incharge_remarks = ? WHERE id = ?',
      [status, incharge_remarks || null, id]
    );

    res.json({ message: `Booking request ${status} successfully.` });
  } catch (error) {
    console.error('Update booking status error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// MY BOOKINGS (Course Coordinator sees own requests)
// ============================================================
const getMyBookingRequests = async (req, res) => {
  try {
    const [requests] = await pool.query(
      `SELECT br.*, 
              p.name as practical_name,
              c.code as course_code, c.name as course_name,
              u2.name as instructor_name,
              (SELECT COUNT(*) FROM booking_comments bc WHERE bc.booking_request_id = br.id) as comment_count
       FROM booking_requests br
       JOIN practicals p ON br.practical_id = p.id
       JOIN courses c ON p.course_id = c.id
       JOIN users u2 ON br.instructor_id = u2.id
       WHERE br.requested_by = ?
       ORDER BY br.booking_date DESC`,
      [req.user.id]
    );
    res.json(requests);
  } catch (error) {
    console.error('Get my bookings error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// INSTRUCTOR SCHEDULE
// ============================================================
const getInstructorSchedule = async (req, res) => {
  try {
    const [requests] = await pool.query(
      `SELECT br.booking_date, br.start_time, br.end_time, br.group_name, br.status,
              p.name as practical_name,
              c.code as course_code, c.name as course_name,
              b.name as batch_name
       FROM booking_requests br
       JOIN practicals p ON br.practical_id = p.id
       JOIN courses c ON p.course_id = c.id
       JOIN semesters s ON c.semester_id = s.id
       JOIN batches b ON s.batch_id = b.id
       WHERE br.instructor_id = ? AND br.status = 'approved'
       ORDER BY br.booking_date ASC, br.start_time ASC`,
      [req.user.id]
    );
    res.json(requests);
  } catch (error) {
    console.error('Get instructor schedule error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

module.exports = {
  createBookingRequest,
  getAllBookingRequests,
  getBookingRequestById,
  getLabAvailability,
  addComment,
  updateBookingStatus,
  getMyBookingRequests,
  getInstructorSchedule
};
