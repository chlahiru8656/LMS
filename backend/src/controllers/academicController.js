const pool = require('../config/db');

// ============================================================
// BATCHES
// ============================================================
const getAllBatches = async (req, res) => {
  try {
    const [batches] = await pool.query('SELECT * FROM batches ORDER BY year DESC');
    res.json(batches);
  } catch (error) {
    console.error('Get batches error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

const createBatch = async (req, res) => {
  try {
    const { name, year } = req.body;
    if (!name || !year) {
      return res.status(400).json({ message: 'Name and year are required.' });
    }
    const [result] = await pool.query('INSERT INTO batches (name, year) VALUES (?, ?)', [name, year]);
    res.status(201).json({ message: 'Batch created successfully.', id: result.insertId });
  } catch (error) {
    console.error('Create batch error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

const updateBatch = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, year, is_active } = req.body;
    await pool.query(
      'UPDATE batches SET name = COALESCE(?, name), year = COALESCE(?, year), is_active = COALESCE(?, is_active) WHERE id = ?',
      [name, year, is_active, id]
    );
    res.json({ message: 'Batch updated successfully.' });
  } catch (error) {
    console.error('Update batch error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

const deleteBatch = async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM batches WHERE id = ?', [id]);
    res.json({ message: 'Batch deleted successfully.' });
  } catch (error) {
    console.error('Delete batch error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// SEMESTERS
// ============================================================
const getSemestersByBatch = async (req, res) => {
  try {
    const { batchId } = req.params;
    const [semesters] = await pool.query(
      'SELECT * FROM semesters WHERE batch_id = ? ORDER BY semester_number',
      [batchId]
    );
    res.json(semesters);
  } catch (error) {
    console.error('Get semesters error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

const createSemester = async (req, res) => {
  try {
    const { batch_id, semester_number, name } = req.body;
    if (!batch_id || !semester_number || !name) {
      return res.status(400).json({ message: 'Batch ID, semester number and name are required.' });
    }
    const [result] = await pool.query(
      'INSERT INTO semesters (batch_id, semester_number, name) VALUES (?, ?, ?)',
      [batch_id, semester_number, name]
    );
    res.status(201).json({ message: 'Semester created successfully.', id: result.insertId });
  } catch (error) {
    console.error('Create semester error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

const updateSemester = async (req, res) => {
  try {
    const { id } = req.params;
    const { semester_number, name, is_active } = req.body;
    await pool.query(
      'UPDATE semesters SET semester_number = COALESCE(?, semester_number), name = COALESCE(?, name), is_active = COALESCE(?, is_active) WHERE id = ?',
      [semester_number, name, is_active, id]
    );
    res.json({ message: 'Semester updated successfully.' });
  } catch (error) {
    console.error('Update semester error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

const deleteSemester = async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM semesters WHERE id = ?', [id]);
    res.json({ message: 'Semester deleted successfully.' });
  } catch (error) {
    console.error('Delete semester error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// COURSES
// ============================================================
const getCoursesBySemester = async (req, res) => {
  try {
    const { semesterId } = req.params;
    const [courses] = await pool.query(
      `SELECT c.*, u.name as coordinator_name 
       FROM courses c 
       LEFT JOIN users u ON c.coordinator_id = u.id 
       WHERE c.semester_id = ? 
       ORDER BY c.code`,
      [semesterId]
    );
    res.json(courses);
  } catch (error) {
    console.error('Get courses error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

const createCourse = async (req, res) => {
  try {
    const { semester_id, code, name, coordinator_id } = req.body;
    if (!semester_id || !code || !name) {
      return res.status(400).json({ message: 'Semester ID, code and name are required.' });
    }
    const [result] = await pool.query(
      'INSERT INTO courses (semester_id, code, name, coordinator_id) VALUES (?, ?, ?, ?)',
      [semester_id, code, name, coordinator_id || null]
    );
    res.status(201).json({ message: 'Course created successfully.', id: result.insertId });
  } catch (error) {
    console.error('Create course error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

const updateCourse = async (req, res) => {
  try {
    const { id } = req.params;
    const { code, name, coordinator_id } = req.body;
    await pool.query(
      'UPDATE courses SET code = COALESCE(?, code), name = COALESCE(?, name), coordinator_id = COALESCE(?, coordinator_id) WHERE id = ?',
      [code, name, coordinator_id, id]
    );
    res.json({ message: 'Course updated successfully.' });
  } catch (error) {
    console.error('Update course error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

const deleteCourse = async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM courses WHERE id = ?', [id]);
    res.json({ message: 'Course deleted successfully.' });
  } catch (error) {
    console.error('Delete course error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// COURSE ENROLLMENTS
// ============================================================
const getEnrollmentsByCourse = async (req, res) => {
  try {
    const { courseId } = req.params;
    const [enrollments] = await pool.query(
      `SELECT ce.*, u.name as student_name, u.email, u.student_staff_id 
       FROM course_enrollments ce 
       JOIN users u ON ce.student_id = u.id 
       WHERE ce.course_id = ? 
       ORDER BY u.name`,
      [courseId]
    );
    res.json(enrollments);
  } catch (error) {
    console.error('Get enrollments error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

const enrollStudent = async (req, res) => {
  try {
    const { course_id, student_id } = req.body;
    if (!course_id || !student_id) {
      return res.status(400).json({ message: 'Course ID and Student ID are required.' });
    }
    const [result] = await pool.query(
      'INSERT INTO course_enrollments (course_id, student_id) VALUES (?, ?)',
      [course_id, student_id]
    );
    res.status(201).json({ message: 'Student enrolled successfully.', id: result.insertId });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ message: 'Student already enrolled in this course.' });
    }
    console.error('Enroll student error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

const bulkEnrollStudents = async (req, res) => {
  try {
    const { course_id, student_ids } = req.body;
    if (!course_id || !student_ids || !Array.isArray(student_ids)) {
      return res.status(400).json({ message: 'Course ID and student IDs array are required.' });
    }

    const values = student_ids.map(sid => [course_id, sid]);
    const [result] = await pool.query(
      'INSERT IGNORE INTO course_enrollments (course_id, student_id) VALUES ?',
      [values]
    );
    res.status(201).json({ message: `${result.affectedRows} students enrolled successfully.` });
  } catch (error) {
    console.error('Bulk enroll error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

const removeEnrollment = async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM course_enrollments WHERE id = ?', [id]);
    res.json({ message: 'Enrollment removed successfully.' });
  } catch (error) {
    console.error('Remove enrollment error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// PRACTICALS
// ============================================================
const getPracticalsByCourse = async (req, res) => {
  try {
    const { courseId } = req.params;
    const [practicals] = await pool.query(
      'SELECT * FROM practicals WHERE course_id = ? ORDER BY name',
      [courseId]
    );
    res.json(practicals);
  } catch (error) {
    console.error('Get practicals error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

const getPracticalById = async (req, res) => {
  try {
    const { id } = req.params;
    const [practicals] = await pool.query('SELECT * FROM practicals WHERE id = ?', [id]);
    if (practicals.length === 0) {
      return res.status(404).json({ message: 'Practical not found.' });
    }

    const practical = practicals[0];

    // Get required equipment
    const [equipment] = await pool.query(
      `SELECT pe.*, e.name as equipment_name, e.model, e.status as equipment_status
       FROM practical_equipment pe 
       JOIN equipment e ON pe.equipment_id = e.id 
       WHERE pe.practical_id = ?`,
      [id]
    );

    // Get required materials
    const [materials] = await pool.query(
      `SELECT pm.*, c.name as consumable_name, c.unit, c.current_stock
       FROM practical_materials pm 
       JOIN consumables c ON pm.consumable_id = c.id 
       WHERE pm.practical_id = ?`,
      [id]
    );

    res.json({ ...practical, equipment, materials });
  } catch (error) {
    console.error('Get practical error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

const createPractical = async (req, res) => {
  try {
    const { course_id, name, description, lab_sheet_url, equipment, materials } = req.body;
    if (!course_id || !name) {
      return res.status(400).json({ message: 'Course ID and name are required.' });
    }

    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();

      const [result] = await connection.query(
        'INSERT INTO practicals (course_id, name, description, lab_sheet_url) VALUES (?, ?, ?, ?)',
        [course_id, name, description || null, lab_sheet_url || null]
      );
      const practicalId = result.insertId;

      // Add required equipment
      if (equipment && equipment.length > 0) {
        const eqValues = equipment.map(e => [practicalId, e.equipment_id, e.quantity_needed || 1]);
        await connection.query(
          'INSERT INTO practical_equipment (practical_id, equipment_id, quantity_needed) VALUES ?',
          [eqValues]
        );
      }

      // Add required materials
      if (materials && materials.length > 0) {
        const matValues = materials.map(m => [practicalId, m.consumable_id, m.quantity_needed]);
        await connection.query(
          'INSERT INTO practical_materials (practical_id, consumable_id, quantity_needed) VALUES ?',
          [matValues]
        );
      }

      await connection.commit();
      res.status(201).json({ message: 'Practical created successfully.', id: practicalId });
    } catch (err) {
      await connection.rollback();
      throw err;
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error('Create practical error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

const updatePractical = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, description, lab_sheet_url, equipment, materials } = req.body;

    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();

      await connection.query(
        'UPDATE practicals SET name = COALESCE(?, name), description = COALESCE(?, description), lab_sheet_url = COALESCE(?, lab_sheet_url) WHERE id = ?',
        [name, description, lab_sheet_url, id]
      );

      // Update equipment if provided
      if (equipment) {
        await connection.query('DELETE FROM practical_equipment WHERE practical_id = ?', [id]);
        if (equipment.length > 0) {
          const eqValues = equipment.map(e => [id, e.equipment_id, e.quantity_needed || 1]);
          await connection.query(
            'INSERT INTO practical_equipment (practical_id, equipment_id, quantity_needed) VALUES ?',
            [eqValues]
          );
        }
      }

      // Update materials if provided
      if (materials) {
        await connection.query('DELETE FROM practical_materials WHERE practical_id = ?', [id]);
        if (materials.length > 0) {
          const matValues = materials.map(m => [id, m.consumable_id, m.quantity_needed]);
          await connection.query(
            'INSERT INTO practical_materials (practical_id, consumable_id, quantity_needed) VALUES ?',
            [matValues]
          );
        }
      }

      await connection.commit();
      res.json({ message: 'Practical updated successfully.' });
    } catch (err) {
      await connection.rollback();
      throw err;
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error('Update practical error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

const deletePractical = async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM practicals WHERE id = ?', [id]);
    res.json({ message: 'Practical deleted successfully.' });
  } catch (error) {
    console.error('Delete practical error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

module.exports = {
  getAllBatches, createBatch, updateBatch, deleteBatch,
  getSemestersByBatch, createSemester, updateSemester, deleteSemester,
  getCoursesBySemester, createCourse, updateCourse, deleteCourse,
  getEnrollmentsByCourse, enrollStudent, bulkEnrollStudents, removeEnrollment,
  getPracticalsByCourse, getPracticalById, createPractical, updatePractical, deletePractical
};
