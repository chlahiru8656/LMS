const pool = require('../config/db');

// ============================================================
// GET DASHBOARD SUMMARY
// ============================================================
const getSummary = async (req, res) => {
  try {
    const [todaysBookings] = await pool.query(
      "SELECT COUNT(*) as count FROM booking_requests WHERE booking_date = CURDATE() AND status = 'approved'"
    );

    const [pendingRequests] = await pool.query(
      "SELECT COUNT(*) as count FROM booking_requests WHERE status = 'pending'"
    );

    const [totalEquipment] = await pool.query(
      "SELECT COUNT(*) as count FROM equipment WHERE approval_status = 'approved'"
    );

    const [lowStockItems] = await pool.query(
      'SELECT COUNT(*) as count FROM consumables WHERE current_stock <= min_threshold'
    );

    res.json({
      todays_bookings: todaysBookings[0].count,
      pending_requests: pendingRequests[0].count,
      total_equipment: totalEquipment[0].count,
      low_stock_items: lowStockItems[0].count
    });
  } catch (error) {
    console.error('Get dashboard summary error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

module.exports = {
  getSummary
};
