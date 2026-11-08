const express = require('express');
const router = express.Router();
const dashboardController = require('../controllers/dashboardController');
const { authenticate, requireApproved } = require('../middleware/auth');

// GET dashboard summary
router.get('/summary', authenticate, requireApproved, dashboardController.getSummary);

module.exports = router;
