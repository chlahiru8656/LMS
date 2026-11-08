const express = require('express');
const router = express.Router();
const bookingController = require('../controllers/bookingController');
const { authenticate, authorize } = require('../middleware/auth');

// All routes require authentication
router.use(authenticate);

// ============================================================
// LAB AVAILABILITY — All authenticated users (privacy-safe)
// ============================================================
router.get('/availability', bookingController.getLabAvailability);

// ============================================================
// BOOKING REQUESTS
// ============================================================

// Course Coordinator creates a booking request
router.post(
  '/',
  authorize('course_coordinator'),
  bookingController.createBookingRequest
);

// Course Coordinator sees own requests
router.get('/my-requests', bookingController.getMyBookingRequests);

// Instructor sees assigned schedule
router.get('/my-schedule', bookingController.getInstructorSchedule);

// Lab staff (TO, Assistant, Incharge, Master Admin) see all requests
router.get(
  '/all',
  authorize('master_admin', 'lab_incharge', 'lab_to', 'lab_assistant'),
  bookingController.getAllBookingRequests
);

// Get single booking with full details (staff only)
router.get(
  '/:id',
  authorize('master_admin', 'lab_incharge', 'lab_to', 'lab_assistant', 'course_coordinator'),
  bookingController.getBookingRequestById
);

// Lab TO / Lab Assistant adds comment
router.post(
  '/:id/comment',
  authorize('lab_to', 'lab_assistant', 'lab_incharge'),
  bookingController.addComment
);

// Lab Incharge approves / rejects
router.put(
  '/:id/status',
  authorize('lab_incharge'),
  bookingController.updateBookingStatus
);

module.exports = router;
