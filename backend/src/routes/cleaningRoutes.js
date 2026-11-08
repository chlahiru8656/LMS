const express = require('express');
const router = express.Router();
const cleaningController = require('../controllers/cleaningController');
const { authenticate, requireApproved, authorizeWithApproval, authorizeDirectAccess } = require('../middleware/auth');

// GET all cleaning schedules
router.get('/schedules', authenticate, requireApproved, cleaningController.getAllSchedules);

// GET single cleaning schedule by ID
router.get('/schedules/:id', authenticate, requireApproved, cleaningController.getScheduleById);

// CREATE cleaning schedule
router.post('/schedules', authenticate, requireApproved, authorizeWithApproval, cleaningController.createSchedule);

// UPDATE cleaning schedule
router.put('/schedules/:id', authenticate, requireApproved, authorizeWithApproval, cleaningController.updateSchedule);

// DELETE cleaning schedule (admin/incharge only)
router.delete('/schedules/:id', authenticate, requireApproved, authorizeDirectAccess, cleaningController.deleteSchedule);

// LOG completion for a schedule
router.post('/schedules/:id/complete', authenticate, requireApproved, authorizeWithApproval, cleaningController.logCompletion);

// GET all cleaning logs
router.get('/logs', authenticate, requireApproved, cleaningController.getCleaningLogs);

// GET overdue schedules
router.get('/overdue', authenticate, requireApproved, cleaningController.getOverdueSchedules);

module.exports = router;
