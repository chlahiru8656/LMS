const jwt = require('jsonwebtoken');
require('dotenv').config();

// Verify JWT token
const authenticate = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'Access denied. No token provided.' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ message: 'Invalid or expired token.' });
  }
};

// Check if user account is approved
const requireApproved = (req, res, next) => {
  if (req.user.status !== 'approved') {
    return res.status(403).json({ message: 'Your account is pending approval.' });
  }
  next();
};

// Role-based authorization
const authorize = (...roles) => {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ message: 'You do not have permission to perform this action.' });
    }
    next();
  };
};

// Master admin or lab incharge (direct access)
const authorizeDirectAccess = (req, res, next) => {
  const directRoles = ['master_admin', 'lab_incharge'];
  if (!directRoles.includes(req.user.role)) {
    return res.status(403).json({ message: 'Only Master Admin or Lab Incharge can perform this action directly.' });
  }
  next();
};

// TO and Assistant actions need approval
const authorizeWithApproval = (req, res, next) => {
  const allowedRoles = ['master_admin', 'lab_incharge', 'lab_to', 'lab_assistant'];
  if (!allowedRoles.includes(req.user.role)) {
    return res.status(403).json({ message: 'You do not have permission to perform this action.' });
  }
  // Mark if this action needs approval
  if (['lab_to', 'lab_assistant'].includes(req.user.role)) {
    req.needsApproval = true;
  } else {
    req.needsApproval = false;
  }
  next();
};

module.exports = {
  authenticate,
  requireApproved,
  authorize,
  authorizeDirectAccess,
  authorizeWithApproval
};
