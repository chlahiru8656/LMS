const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { authenticate, authorize } = require('../middleware/auth');

// Public routes
router.post('/register', authController.register);
router.post('/login', authController.login);

// Protected routes
router.get('/profile', authenticate, authController.getProfile);
router.put('/profile', authenticate, authController.updateProfile);
router.put('/change-password', authenticate, authController.changePassword);

// Master Admin only
router.get('/users', authenticate, authorize('master_admin'), authController.getAllUsers);
router.get('/users/pending', authenticate, authorize('master_admin'), authController.getPendingUsers);
router.put('/users/:id/status', authenticate, authorize('master_admin'), authController.updateUserStatus);
router.put('/users/:id/role', authenticate, authorize('master_admin'), authController.updateUserRole);

module.exports = router;
