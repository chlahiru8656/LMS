const express = require('express');
const router = express.Router();
const academicController = require('../controllers/academicController');
const { authenticate, authorize } = require('../middleware/auth');

// All routes require authentication
router.use(authenticate);

// ============================================================
// BATCHES — Master Admin only for CUD, all authenticated can read
// ============================================================
router.get('/batches', academicController.getAllBatches);
router.post('/batches', authorize('master_admin'), academicController.createBatch);
router.put('/batches/:id', authorize('master_admin'), academicController.updateBatch);
router.delete('/batches/:id', authorize('master_admin'), academicController.deleteBatch);

// ============================================================
// SEMESTERS
// ============================================================
router.get('/semesters/batch/:batchId', academicController.getSemestersByBatch);
router.post('/semesters', authorize('master_admin'), academicController.createSemester);
router.put('/semesters/:id', authorize('master_admin'), academicController.updateSemester);
router.delete('/semesters/:id', authorize('master_admin'), academicController.deleteSemester);

// ============================================================
// COURSES
// ============================================================
router.get('/courses/semester/:semesterId', academicController.getCoursesBySemester);
router.post('/courses', authorize('master_admin'), academicController.createCourse);
router.put('/courses/:id', authorize('master_admin'), academicController.updateCourse);
router.delete('/courses/:id', authorize('master_admin'), academicController.deleteCourse);

// ============================================================
// ENROLLMENTS — Master Admin only
// ============================================================
router.get('/enrollments/course/:courseId', academicController.getEnrollmentsByCourse);
router.post('/enrollments', authorize('master_admin'), academicController.enrollStudent);
router.post('/enrollments/bulk', authorize('master_admin'), academicController.bulkEnrollStudents);
router.delete('/enrollments/:id', authorize('master_admin'), academicController.removeEnrollment);

// ============================================================
// PRACTICALS — Master Admin only for CUD
// ============================================================
router.get('/practicals/course/:courseId', academicController.getPracticalsByCourse);
router.get('/practicals/:id', academicController.getPracticalById);
router.post('/practicals', authorize('master_admin'), academicController.createPractical);
router.put('/practicals/:id', authorize('master_admin'), academicController.updatePractical);
router.delete('/practicals/:id', authorize('master_admin'), academicController.deletePractical);

module.exports = router;
