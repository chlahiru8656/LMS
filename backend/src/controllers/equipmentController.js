const pool = require('../config/db');

// ============================================================
// GET ALL EQUIPMENT
// ============================================================
const getAllEquipment = async (req, res) => {
  try {
    const { status } = req.query;
    let query = 'SELECT * FROM equipment WHERE 1=1';
    const params = [];

    if (status) {
      query += ' AND status = ?';
      params.push(status);
    }

    query += ' ORDER BY name ASC';

    const [rows] = await pool.query(query, params);
    res.json(rows);
  } catch (error) {
    console.error('Get all equipment error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// GET EQUIPMENT BY ID
// ============================================================
const getEquipmentById = async (req, res) => {
  try {
    const { id } = req.params;

    const [equipment] = await pool.query('SELECT * FROM equipment WHERE id = ?', [id]);
    if (equipment.length === 0) {
      return res.status(404).json({ message: 'Equipment not found.' });
    }

    // Get recent maintenance logs
    const [maintenanceLogs] = await pool.query(
      `SELECT ml.*, u.name as performed_by_name
       FROM maintenance_logs ml
       LEFT JOIN users u ON ml.performed_by = u.id
       WHERE ml.equipment_id = ?
       ORDER BY ml.maintenance_date DESC
       LIMIT 10`,
      [id]
    );

    // Get recent calibrations
    const [calibrations] = await pool.query(
      `SELECT cal.*, u.name as performed_by_name
       FROM calibrations cal
       LEFT JOIN users u ON cal.performed_by = u.id
       WHERE cal.equipment_id = ?
       ORDER BY cal.calibration_date DESC
       LIMIT 10`,
      [id]
    );

    res.json({ ...equipment[0], maintenance_logs: maintenanceLogs, calibrations });
  } catch (error) {
    console.error('Get equipment by ID error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// CREATE EQUIPMENT
// ============================================================
const createEquipment = async (req, res) => {
  try {
    const { name, model, serial_number, manufacturer, location_in_lab, status, description, next_calibration_due } = req.body;

    if (!name) {
      return res.status(400).json({ message: 'Equipment name is required.' });
    }

    const approvalStatus = req.needsApproval ? 'pending' : 'approved';

    const [result] = await pool.query(
      `INSERT INTO equipment (name, model, serial_number, manufacturer, location_in_lab, status, description, next_calibration_due, approval_status, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [name, model || null, serial_number || null, manufacturer || null, location_in_lab || null, status || 'available', description || null, next_calibration_due || null, approvalStatus, req.user.id]
    );

    res.status(201).json({ message: 'Equipment created successfully.', id: result.insertId });
  } catch (error) {
    console.error('Create equipment error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// UPDATE EQUIPMENT
// ============================================================
const updateEquipment = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, model, serial_number, manufacturer, location_in_lab, status, description, next_calibration_due } = req.body;

    const [existing] = await pool.query('SELECT * FROM equipment WHERE id = ?', [id]);
    if (existing.length === 0) {
      return res.status(404).json({ message: 'Equipment not found.' });
    }

    // If user needs approval and equipment was previously approved, set back to pending
    let approvalStatus = existing[0].approval_status;
    if (req.needsApproval && existing[0].approval_status === 'approved') {
      approvalStatus = 'pending';
    }

    await pool.query(
      `UPDATE equipment SET name = ?, model = ?, serial_number = ?, manufacturer = ?, location_in_lab = ?, status = ?, description = ?, next_calibration_due = ?, approval_status = ?
       WHERE id = ?`,
      [
        name || existing[0].name,
        model !== undefined ? model : existing[0].model,
        serial_number !== undefined ? serial_number : existing[0].serial_number,
        manufacturer !== undefined ? manufacturer : existing[0].manufacturer,
        location_in_lab !== undefined ? location_in_lab : existing[0].location_in_lab,
        status || existing[0].status,
        description !== undefined ? description : existing[0].description,
        next_calibration_due !== undefined ? next_calibration_due : existing[0].next_calibration_due,
        approvalStatus,
        id
      ]
    );

    res.json({ message: 'Equipment updated successfully.' });
  } catch (error) {
    console.error('Update equipment error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// DELETE EQUIPMENT (admin/incharge only)
// ============================================================
const deleteEquipment = async (req, res) => {
  try {
    const { id } = req.params;

    const [existing] = await pool.query('SELECT id FROM equipment WHERE id = ?', [id]);
    if (existing.length === 0) {
      return res.status(404).json({ message: 'Equipment not found.' });
    }

    await pool.query('DELETE FROM equipment WHERE id = ?', [id]);
    res.json({ message: 'Equipment deleted successfully.' });
  } catch (error) {
    console.error('Delete equipment error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// LOG MAINTENANCE
// ============================================================
const logMaintenance = async (req, res) => {
  try {
    const { id } = req.params; // equipment_id
    const { maintenance_date, maintenance_type, description, performed_by, cost } = req.body;

    if (!maintenance_date || !maintenance_type) {
      return res.status(400).json({ message: 'Maintenance date and type are required.' });
    }

    // Verify equipment exists
    const [equipment] = await pool.query('SELECT id FROM equipment WHERE id = ?', [id]);
    if (equipment.length === 0) {
      return res.status(404).json({ message: 'Equipment not found.' });
    }

    const [result] = await pool.query(
      `INSERT INTO maintenance_logs (equipment_id, maintenance_date, maintenance_type, description, performed_by, cost, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [id, maintenance_date, maintenance_type, description || null, performed_by || null, cost || null, req.user.id]
    );

    res.status(201).json({ message: 'Maintenance log recorded successfully.', id: result.insertId });
  } catch (error) {
    console.error('Log maintenance error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// GET MAINTENANCE LOGS
// ============================================================
const getMaintenanceLogs = async (req, res) => {
  try {
    const { id } = req.params; // equipment_id

    const [logs] = await pool.query(
      `SELECT ml.*, u.name as performed_by_name, u2.name as created_by_name
       FROM maintenance_logs ml
       LEFT JOIN users u ON ml.performed_by = u.id
       LEFT JOIN users u2 ON ml.created_by = u2.id
       WHERE ml.equipment_id = ?
       ORDER BY ml.maintenance_date DESC`,
      [id]
    );

    res.json(logs);
  } catch (error) {
    console.error('Get maintenance logs error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// LOG CALIBRATION
// ============================================================
const logCalibration = async (req, res) => {
  try {
    const { id } = req.params; // equipment_id
    const { calibration_date, next_due_date, performed_by, certificate_number, remarks } = req.body;

    if (!calibration_date || !next_due_date) {
      return res.status(400).json({ message: 'Calibration date and next due date are required.' });
    }

    // Verify equipment exists
    const [equipment] = await pool.query('SELECT id FROM equipment WHERE id = ?', [id]);
    if (equipment.length === 0) {
      return res.status(404).json({ message: 'Equipment not found.' });
    }

    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();

      const [result] = await connection.query(
        `INSERT INTO calibrations (equipment_id, calibration_date, next_due_date, performed_by, certificate_number, remarks, created_by)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [id, calibration_date, next_due_date, performed_by || null, certificate_number || null, remarks || null, req.user.id]
      );

      // Update next calibration due on equipment
      await connection.query(
        'UPDATE equipment SET next_calibration_due = ? WHERE id = ?',
        [next_due_date, id]
      );

      await connection.commit();
      res.status(201).json({ message: 'Calibration log recorded successfully.', id: result.insertId });
    } catch (err) {
      await connection.rollback();
      throw err;
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error('Log calibration error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// GET CALIBRATIONS
// ============================================================
const getCalibrations = async (req, res) => {
  try {
    const { id } = req.params; // equipment_id

    const [calibrations] = await pool.query(
      `SELECT cal.*, u.name as performed_by_name, u2.name as created_by_name
       FROM calibrations cal
       LEFT JOIN users u ON cal.performed_by = u.id
       LEFT JOIN users u2 ON cal.created_by = u2.id
       WHERE cal.equipment_id = ?
       ORDER BY cal.calibration_date DESC`,
      [id]
    );

    res.json(calibrations);
  } catch (error) {
    console.error('Get calibrations error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// APPROVE EQUIPMENT (admin/incharge only)
// ============================================================
const approveEquipment = async (req, res) => {
  try {
    const { id } = req.params;

    const [existing] = await pool.query('SELECT id, approval_status FROM equipment WHERE id = ?', [id]);
    if (existing.length === 0) {
      return res.status(404).json({ message: 'Equipment not found.' });
    }

    await pool.query(
      "UPDATE equipment SET approval_status = 'approved', approved_by = ? WHERE id = ?",
      [req.user.id, id]
    );

    res.json({ message: 'Equipment approved successfully.' });
  } catch (error) {
    console.error('Approve equipment error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

module.exports = {
  getAllEquipment,
  getEquipmentById,
  createEquipment,
  updateEquipment,
  deleteEquipment,
  logMaintenance,
  getMaintenanceLogs,
  logCalibration,
  getCalibrations,
  approveEquipment
};
