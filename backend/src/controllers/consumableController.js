const pool = require('../config/db');

// ============================================================
// GET ALL CONSUMABLES
// ============================================================
const getAllConsumables = async (req, res) => {
  try {
    const { low_stock } = req.query;
    let query = 'SELECT * FROM consumables WHERE 1=1';
    const params = [];

    if (low_stock === 'true') {
      query += ' AND current_stock <= min_threshold';
    }

    query += ' ORDER BY name ASC';

    const [rows] = await pool.query(query, params);
    res.json(rows);
  } catch (error) {
    console.error('Get all consumables error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// GET CONSUMABLE BY ID
// ============================================================
const getConsumableById = async (req, res) => {
  try {
    const { id } = req.params;

    const [consumable] = await pool.query('SELECT * FROM consumables WHERE id = ?', [id]);
    if (consumable.length === 0) {
      return res.status(404).json({ message: 'Consumable not found.' });
    }

    // Get recent usage logs
    const [usageLogs] = await pool.query(
      `SELECT ul.*, u.name as used_by_name
       FROM usage_logs ul
       LEFT JOIN users u ON ul.used_by = u.id
       WHERE ul.consumable_id = ?
       ORDER BY ul.usage_date DESC
       LIMIT 10`,
      [id]
    );

    // Get recent replenishments
    const [replenishments] = await pool.query(
      `SELECT r.*, u.name as created_by_name
       FROM replenishments r
       LEFT JOIN users u ON r.created_by = u.id
       WHERE r.consumable_id = ?
       ORDER BY r.created_at DESC
       LIMIT 10`,
      [id]
    );

    res.json({ ...consumable[0], usage_logs: usageLogs, replenishments });
  } catch (error) {
    console.error('Get consumable by ID error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// CREATE CONSUMABLE
// ============================================================
const createConsumable = async (req, res) => {
  try {
    const { name, category, unit, current_stock, min_threshold } = req.body;

    if (!name) {
      return res.status(400).json({ message: 'Consumable name is required.' });
    }

    const approvalStatus = req.needsApproval ? 'pending' : 'approved';

    const [result] = await pool.query(
      `INSERT INTO consumables (name, category, unit, current_stock, min_threshold, approval_status, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [name, category || null, unit || null, current_stock || 0, min_threshold || 0, approvalStatus, req.user.id]
    );

    res.status(201).json({ message: 'Consumable created successfully.', id: result.insertId });
  } catch (error) {
    console.error('Create consumable error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// UPDATE CONSUMABLE
// ============================================================
const updateConsumable = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, category, unit, current_stock, min_threshold } = req.body;

    const [existing] = await pool.query('SELECT * FROM consumables WHERE id = ?', [id]);
    if (existing.length === 0) {
      return res.status(404).json({ message: 'Consumable not found.' });
    }

    await pool.query(
      `UPDATE consumables SET name = ?, category = ?, unit = ?, current_stock = ?, min_threshold = ?
       WHERE id = ?`,
      [
        name || existing[0].name,
        category !== undefined ? category : existing[0].category,
        unit !== undefined ? unit : existing[0].unit,
        current_stock !== undefined ? current_stock : existing[0].current_stock,
        min_threshold !== undefined ? min_threshold : existing[0].min_threshold,
        id
      ]
    );

    res.json({ message: 'Consumable updated successfully.' });
  } catch (error) {
    console.error('Update consumable error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// DELETE CONSUMABLE (admin/incharge only)
// ============================================================
const deleteConsumable = async (req, res) => {
  try {
    const { id } = req.params;

    const [existing] = await pool.query('SELECT id FROM consumables WHERE id = ?', [id]);
    if (existing.length === 0) {
      return res.status(404).json({ message: 'Consumable not found.' });
    }

    await pool.query('DELETE FROM consumables WHERE id = ?', [id]);
    res.json({ message: 'Consumable deleted successfully.' });
  } catch (error) {
    console.error('Delete consumable error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// RECORD USAGE
// ============================================================
const recordUsage = async (req, res) => {
  try {
    const { id } = req.params; // consumable_id
    const { quantity_used, usage_date, purpose } = req.body;

    if (!quantity_used || !usage_date) {
      return res.status(400).json({ message: 'Quantity used and usage date are required.' });
    }

    // Verify consumable exists
    const [consumable] = await pool.query('SELECT id, current_stock FROM consumables WHERE id = ?', [id]);
    if (consumable.length === 0) {
      return res.status(404).json({ message: 'Consumable not found.' });
    }

    if (consumable[0].current_stock < quantity_used) {
      return res.status(400).json({ message: 'Insufficient stock.' });
    }

    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();

      const [result] = await connection.query(
        `INSERT INTO usage_logs (consumable_id, quantity_used, usage_date, purpose, used_by)
         VALUES (?, ?, ?, ?, ?)`,
        [id, quantity_used, usage_date, purpose || null, req.user.id]
      );

      await connection.query(
        'UPDATE consumables SET current_stock = current_stock - ? WHERE id = ?',
        [quantity_used, id]
      );

      await connection.commit();
      res.status(201).json({ message: 'Usage recorded successfully.', id: result.insertId });
    } catch (err) {
      await connection.rollback();
      throw err;
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error('Record usage error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// GET USAGE LOGS
// ============================================================
const getUsageLogs = async (req, res) => {
  try {
    const { id } = req.params; // consumable_id

    const [logs] = await pool.query(
      `SELECT ul.*, u.name as used_by_name
       FROM usage_logs ul
       LEFT JOIN users u ON ul.used_by = u.id
       WHERE ul.consumable_id = ?
       ORDER BY ul.usage_date DESC`,
      [id]
    );

    res.json(logs);
  } catch (error) {
    console.error('Get usage logs error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// RECORD REPLENISHMENT
// ============================================================
const recordReplenishment = async (req, res) => {
  try {
    const { id } = req.params; // consumable_id
    const { quantity_added, supplier, cost, remarks } = req.body;

    if (!quantity_added) {
      return res.status(400).json({ message: 'Quantity added is required.' });
    }

    // Verify consumable exists
    const [consumable] = await pool.query('SELECT id FROM consumables WHERE id = ?', [id]);
    if (consumable.length === 0) {
      return res.status(404).json({ message: 'Consumable not found.' });
    }

    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();

      const [result] = await connection.query(
        `INSERT INTO replenishments (consumable_id, quantity_added, supplier, cost, remarks, created_by)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [id, quantity_added, supplier || null, cost || null, remarks || null, req.user.id]
      );

      await connection.query(
        'UPDATE consumables SET current_stock = current_stock + ? WHERE id = ?',
        [quantity_added, id]
      );

      await connection.commit();
      res.status(201).json({ message: 'Replenishment recorded successfully.', id: result.insertId });
    } catch (err) {
      await connection.rollback();
      throw err;
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error('Record replenishment error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// GET REPLENISHMENTS
// ============================================================
const getReplenishments = async (req, res) => {
  try {
    const { id } = req.params; // consumable_id

    const [replenishments] = await pool.query(
      `SELECT r.*, u.name as created_by_name
       FROM replenishments r
       LEFT JOIN users u ON r.created_by = u.id
       WHERE r.consumable_id = ?
       ORDER BY r.created_at DESC`,
      [id]
    );

    res.json(replenishments);
  } catch (error) {
    console.error('Get replenishments error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// GET LOW STOCK ITEMS
// ============================================================
const getLowStockItems = async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT * FROM consumables WHERE current_stock <= min_threshold ORDER BY name ASC'
    );
    res.json(rows);
  } catch (error) {
    console.error('Get low stock items error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// APPROVE CONSUMABLE (admin/incharge only)
// ============================================================
const approveConsumable = async (req, res) => {
  try {
    const { id } = req.params;

    const [existing] = await pool.query('SELECT id, approval_status FROM consumables WHERE id = ?', [id]);
    if (existing.length === 0) {
      return res.status(404).json({ message: 'Consumable not found.' });
    }

    await pool.query(
      "UPDATE consumables SET approval_status = 'approved', approved_by = ? WHERE id = ?",
      [req.user.id, id]
    );

    res.json({ message: 'Consumable approved successfully.' });
  } catch (error) {
    console.error('Approve consumable error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

module.exports = {
  getAllConsumables,
  getConsumableById,
  createConsumable,
  updateConsumable,
  deleteConsumable,
  recordUsage,
  getUsageLogs,
  recordReplenishment,
  getReplenishments,
  getLowStockItems,
  approveConsumable
};
