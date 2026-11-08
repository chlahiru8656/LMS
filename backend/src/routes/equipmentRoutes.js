const express = require('express');
const router = express.Router();
const equipmentController = require('../controllers/equipmentController');
const { authenticate, requireApproved, authorizeWithApproval, authorizeDirectAccess } = require('../middleware/auth');

// GET all equipment
router.get('/', authenticate, requireApproved, equipmentController.getAllEquipment);

// GET single equipment by ID
router.get('/:id', authenticate, requireApproved, equipmentController.getEquipmentById);

// CREATE equipment
router.post('/', authenticate, requireApproved, authorizeWithApproval, equipmentController.createEquipment);

// UPDATE equipment
router.put('/:id', authenticate, requireApproved, authorizeWithApproval, equipmentController.updateEquipment);

// DELETE equipment (admin/incharge only)
router.delete('/:id', authenticate, requireApproved, authorizeDirectAccess, equipmentController.deleteEquipment);

// LOG maintenance for equipment
router.post('/:id/maintenance', authenticate, requireApproved, authorizeWithApproval, equipmentController.logMaintenance);

// GET maintenance logs for equipment
router.get('/:id/maintenance', authenticate, requireApproved, equipmentController.getMaintenanceLogs);

// LOG calibration for equipment
router.post('/:id/calibration', authenticate, requireApproved, authorizeWithApproval, equipmentController.logCalibration);

// GET calibrations for equipment
router.get('/:id/calibration', authenticate, requireApproved, equipmentController.getCalibrations);

// APPROVE equipment (admin/incharge only)
router.put('/:id/approve', authenticate, requireApproved, authorizeDirectAccess, equipmentController.approveEquipment);

module.exports = router;
