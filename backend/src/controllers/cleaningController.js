const pool = require('../config/db');

// ============================================================
// GET ALL CLEANING SCHEDULES
// ============================================================
const getAllSchedules = async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT cs.*, e.name as equipment_name
       FROM cleaning_schedules cs
       LEFT JOIN equipment e ON cs.equipment_id = e.id
       ORDER BY cs.created_at DESC`
    );
    res.json(rows);
  } catch (error) {
    console.error('Get all cleaning schedules error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// GET SCHEDULE BY ID
// ============================================================
const getScheduleById = async (req, res) => {
  try {
    const { id } = req.params;

    const [schedule] = await pool.query(
      `SELECT cs.*, e.name as equipment_name
       FROM cleaning_schedules cs
       LEFT JOIN equipment e ON cs.equipment_id = e.id
       WHERE cs.id = ?`,
      [id]
    );

    if (schedule.length === 0) {
      return res.status(404).json({ message: 'Cleaning schedule not found.' });
    }

    // Get cleaning logs for this schedule
    const [logs] = await pool.query(
      `SELECT cl.*, u.name as completed_by_name
       FROM cleaning_logs cl
       LEFT JOIN users u ON cl.completed_by = u.id
       WHERE cl.schedule_id = ?
       ORDER BY cl.scheduled_date DESC`,
      [id]
    );

    res.json({ ...schedule[0], cleaning_logs: logs });
  } catch (error) {
    console.error('Get schedule by ID error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// CREATE CLEANING SCHEDULE
// ============================================================
const createSchedule = async (req, res) => {
  try {
    const { equipment_id, task_name, description, frequency, assigned_to, scheduled_time, day_of_week, day_of_month } = req.body;

    if (!task_name || !frequency) {
      return res.status(400).json({ message: 'Task name and frequency are required.' });
    }

    const [result] = await pool.query(
      `INSERT INTO cleaning_schedules (equipment_id, task_name, description, frequency, assigned_to, scheduled_time, day_of_week, day_of_month, lab_id, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?)`,
      [equipment_id || null, task_name, description || null, frequency, assigned_to || null, scheduled_time || null, day_of_week || null, day_of_month || null, req.user.id]
    );

    res.status(201).json({ message: 'Cleaning schedule created successfully.', id: result.insertId });
  } catch (error) {
    console.error('Create cleaning schedule error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// UPDATE CLEANING SCHEDULE
// ============================================================
const updateSchedule = async (req, res) => {
  try {
    const { id } = req.params;
    const { equipment_id, task_name, description, frequency, assigned_to, scheduled_time, day_of_week, day_of_month } = req.body;

    const [existing] = await pool.query('SELECT * FROM cleaning_schedules WHERE id = ?', [id]);
    if (existing.length === 0) {
      return res.status(404).json({ message: 'Cleaning schedule not found.' });
    }

    await pool.query(
      `UPDATE cleaning_schedules SET equipment_id = ?, task_name = ?, description = ?, frequency = ?, assigned_to = ?, scheduled_time = ?, day_of_week = ?, day_of_month = ?
       WHERE id = ?`,
      [
        equipment_id !== undefined ? equipment_id : existing[0].equipment_id,
        task_name || existing[0].task_name,
        description !== undefined ? description : existing[0].description,
        frequency || existing[0].frequency,
        assigned_to !== undefined ? assigned_to : existing[0].assigned_to,
        scheduled_time !== undefined ? scheduled_time : existing[0].scheduled_time,
        day_of_week !== undefined ? day_of_week : existing[0].day_of_week,
        day_of_month !== undefined ? day_of_month : existing[0].day_of_month,
        id
      ]
    );

    res.json({ message: 'Cleaning schedule updated successfully.' });
  } catch (error) {
    console.error('Update cleaning schedule error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// DELETE CLEANING SCHEDULE (admin/incharge only)
// ============================================================
const deleteSchedule = async (req, res) => {
  try {
    const { id } = req.params;

    const [existing] = await pool.query('SELECT id FROM cleaning_schedules WHERE id = ?', [id]);
    if (existing.length === 0) {
      return res.status(404).json({ message: 'Cleaning schedule not found.' });
    }

    await pool.query('DELETE FROM cleaning_schedules WHERE id = ?', [id]);
    res.json({ message: 'Cleaning schedule deleted successfully.' });
  } catch (error) {
    console.error('Delete cleaning schedule error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// LOG COMPLETION
// ============================================================
const logCompletion = async (req, res) => {
  try {
    const { id } = req.params; // schedule_id
    const { completed_date, completed_time, remarks } = req.body;

    if (!completed_date) {
      return res.status(400).json({ message: 'Completed date is required.' });
    }

    // Verify schedule exists
    const [schedule] = await pool.query('SELECT id FROM cleaning_schedules WHERE id = ?', [id]);
    if (schedule.length === 0) {
      return res.status(404).json({ message: 'Cleaning schedule not found.' });
    }

    // Check if there's a pending log for this schedule and date, update it
    const [existingLog] = await pool.query(
      "SELECT id FROM cleaning_logs WHERE schedule_id = ? AND scheduled_date = ? AND status = 'pending'",
      [id, completed_date]
    );

    if (existingLog.length > 0) {
      await pool.query(
        "UPDATE cleaning_logs SET completed_date = ?, completed_time = ?, completed_by = ?, remarks = ?, status = 'completed' WHERE id = ?",
        [completed_date, completed_time || null, req.user.id, remarks || null, existingLog[0].id]
      );
      res.json({ message: 'Cleaning log updated to completed.', id: existingLog[0].id });
    } else {
      const [result] = await pool.query(
        "INSERT INTO cleaning_logs (schedule_id, scheduled_date, completed_date, completed_time, completed_by, remarks, status) VALUES (?, ?, ?, ?, ?, ?, 'completed')",
        [id, completed_date, completed_date, completed_time || null, req.user.id, remarks || null]
      );
      res.status(201).json({ message: 'Cleaning completion logged successfully.', id: result.insertId });
    }
  } catch (error) {
    console.error('Log completion error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// GET CLEANING LOGS
// ============================================================
const getCleaningLogs = async (req, res) => {
  try {
    const { status, from, to } = req.query;
    let query = `
      SELECT cl.*, cs.task_name, cs.frequency, e.name as equipment_name, u.name as completed_by_name
      FROM cleaning_logs cl
      JOIN cleaning_schedules cs ON cl.schedule_id = cs.id
      LEFT JOIN equipment e ON cs.equipment_id = e.id
      LEFT JOIN users u ON cl.completed_by = u.id
      WHERE 1=1
    `;
    const params = [];

    if (status) {
      query += ' AND cl.status = ?';
      params.push(status);
    }
    if (from) {
      query += ' AND cl.scheduled_date >= ?';
      params.push(from);
    }
    if (to) {
      query += ' AND cl.scheduled_date <= ?';
      params.push(to);
    }

    query += ' ORDER BY cl.scheduled_date DESC';

    const [logs] = await pool.query(query, params);
    res.json(logs);
  } catch (error) {
    console.error('Get cleaning logs error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// GET OVERDUE SCHEDULES
// ============================================================
const getOverdueSchedules = async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT cl.*, cs.task_name, cs.frequency, e.name as equipment_name
       FROM cleaning_logs cl
       JOIN cleaning_schedules cs ON cl.schedule_id = cs.id
       LEFT JOIN equipment e ON cs.equipment_id = e.id
       WHERE cl.status = 'pending' AND cl.scheduled_date < CURDATE()
       ORDER BY cl.scheduled_date ASC`
    );
    res.json(rows);
  } catch (error) {
    console.error('Get overdue schedules error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

module.exports = {
  getAllSchedules,
  getScheduleById,
  createSchedule,
  updateSchedule,
  deleteSchedule,
  logCompletion,
  getCleaningLogs,
  getOverdueSchedules
};
