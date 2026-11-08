const express = require('express');
const router = express.Router();
const consumableController = require('../controllers/consumableController');
const { authenticate, requireApproved, authorizeWithApproval, authorizeDirectAccess } = require('../middleware/auth');

// GET all consumables
router.get('/', authenticate, requireApproved, consumableController.getAllConsumables);

// GET low stock items (must be before /:id to avoid conflict)
router.get('/low-stock', authenticate, requireApproved, consumableController.getLowStockItems);

// GET single consumable by ID
router.get('/:id', authenticate, requireApproved, consumableController.getConsumableById);

// CREATE consumable
router.post('/', authenticate, requireApproved, authorizeWithApproval, consumableController.createConsumable);

// UPDATE consumable
router.put('/:id', authenticate, requireApproved, authorizeWithApproval, consumableController.updateConsumable);

// DELETE consumable (admin/incharge only)
router.delete('/:id', authenticate, requireApproved, authorizeDirectAccess, consumableController.deleteConsumable);

// RECORD usage for consumable
router.post('/:id/usage', authenticate, requireApproved, authorizeWithApproval, consumableController.recordUsage);

// GET usage logs for consumable
router.get('/:id/usage', authenticate, requireApproved, consumableController.getUsageLogs);

// RECORD replenishment for consumable
router.post('/:id/replenish', authenticate, requireApproved, authorizeWithApproval, consumableController.recordReplenishment);

// GET replenishments for consumable
router.get('/:id/replenish', authenticate, requireApproved, consumableController.getReplenishments);

// APPROVE consumable (admin/incharge only)
router.put('/:id/approve', authenticate, requireApproved, authorizeDirectAccess, consumableController.approveConsumable);

module.exports = router;
