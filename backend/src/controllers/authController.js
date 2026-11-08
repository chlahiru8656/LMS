const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');
require('dotenv').config();

// Register a new user
const register = async (req, res) => {
  try {
    const { name, email, password, role, student_staff_id, phone } = req.body;

    // Validate required fields
    if (!name || !email || !password) {
      return res.status(400).json({ message: 'Name, email and password are required.' });
    }

    // Check if email already exists
    const [existing] = await pool.query('SELECT id FROM users WHERE email = ?', [email]);
    if (existing.length > 0) {
      return res.status(409).json({ message: 'Email already registered.' });
    }

    // Check if student_staff_id already exists
    if (student_staff_id) {
      const [existingId] = await pool.query('SELECT id FROM users WHERE student_staff_id = ?', [student_staff_id]);
      if (existingId.length > 0) {
        return res.status(409).json({ message: 'Student/Staff ID already registered.' });
      }
    }

    // Hash password
    const salt = await bcrypt.genSalt(10);
    const password_hash = await bcrypt.hash(password, salt);

    // Determine approval status
    // Staff roles (non-student) are auto-approved; students need admin approval
    const userRole = role || 'student';
    const status = userRole === 'student' ? 'pending' : 'approved';

    const [result] = await pool.query(
      'INSERT INTO users (name, email, password_hash, role, student_staff_id, phone, status) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [name, email, password_hash, userRole, student_staff_id || null, phone || null, status]
    );

    res.status(201).json({
      message: userRole === 'student'
        ? 'Registration successful. Your account is pending admin approval.'
        : 'Registration successful.',
      userId: result.insertId
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ message: 'Server error during registration.' });
  }
};

// Login
const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: 'Email and password are required.' });
    }

    // Find user
    const [users] = await pool.query('SELECT * FROM users WHERE email = ?', [email]);
    if (users.length === 0) {
      return res.status(401).json({ message: 'Invalid email or password.' });
    }

    const user = users[0];

    // Check password
    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res.status(401).json({ message: 'Invalid email or password.' });
    }

    // Check if account is approved (for students)
    if (user.status === 'rejected') {
      return res.status(403).json({ message: 'Your registration has been rejected.' });
    }

    // Generate JWT
    const token = jwt.sign(
      {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        status: user.status
      },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN }
    );

    res.json({
      message: 'Login successful.',
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        student_staff_id: user.student_staff_id,
        phone: user.phone,
        status: user.status
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ message: 'Server error during login.' });
  }
};

// Get current user profile
const getProfile = async (req, res) => {
  try {
    const [users] = await pool.query(
      'SELECT id, name, email, role, student_staff_id, phone, status, created_at FROM users WHERE id = ?',
      [req.user.id]
    );
    if (users.length === 0) {
      return res.status(404).json({ message: 'User not found.' });
    }
    res.json(users[0]);
  } catch (error) {
    console.error('Profile error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// Update profile
const updateProfile = async (req, res) => {
  try {
    const { name, phone } = req.body;
    await pool.query(
      'UPDATE users SET name = COALESCE(?, name), phone = COALESCE(?, phone) WHERE id = ?',
      [name, phone, req.user.id]
    );
    res.json({ message: 'Profile updated successfully.' });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// Change password
const changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({ message: 'Current and new passwords are required.' });
    }

    const [users] = await pool.query('SELECT password_hash FROM users WHERE id = ?', [req.user.id]);
    const isMatch = await bcrypt.compare(currentPassword, users[0].password_hash);
    if (!isMatch) {
      return res.status(401).json({ message: 'Current password is incorrect.' });
    }

    const salt = await bcrypt.genSalt(10);
    const newHash = await bcrypt.hash(newPassword, salt);
    await pool.query('UPDATE users SET password_hash = ? WHERE id = ?', [newHash, req.user.id]);

    res.json({ message: 'Password changed successfully.' });
  } catch (error) {
    console.error('Change password error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// ============================================================
// ADMIN: User Management
// ============================================================

// Get all pending student registrations
const getPendingUsers = async (req, res) => {
  try {
    const [users] = await pool.query(
      'SELECT id, name, email, role, student_staff_id, phone, status, created_at FROM users WHERE status = ? ORDER BY created_at DESC',
      ['pending']
    );
    res.json(users);
  } catch (error) {
    console.error('Get pending users error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// Get all users
const getAllUsers = async (req, res) => {
  try {
    const [users] = await pool.query(
      'SELECT id, name, email, role, student_staff_id, phone, status, created_at FROM users ORDER BY created_at DESC'
    );
    res.json(users);
  } catch (error) {
    console.error('Get all users error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// Approve or reject a user registration
const updateUserStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body; // 'approved' or 'rejected'

    if (!['approved', 'rejected'].includes(status)) {
      return res.status(400).json({ message: 'Status must be approved or rejected.' });
    }

    const [result] = await pool.query('UPDATE users SET status = ? WHERE id = ?', [status, id]);
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'User not found.' });
    }

    res.json({ message: `User ${status} successfully.` });
  } catch (error) {
    console.error('Update user status error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

// Update user role
const updateUserRole = async (req, res) => {
  try {
    const { id } = req.params;
    const { role } = req.body;

    const validRoles = ['master_admin', 'course_coordinator', 'instructor', 'lab_incharge', 'lab_to', 'lab_assistant', 'student'];
    if (!validRoles.includes(role)) {
      return res.status(400).json({ message: 'Invalid role.' });
    }

    const [result] = await pool.query('UPDATE users SET role = ? WHERE id = ?', [role, id]);
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: 'User not found.' });
    }

    res.json({ message: 'User role updated successfully.' });
  } catch (error) {
    console.error('Update user role error:', error);
    res.status(500).json({ message: 'Server error.' });
  }
};

module.exports = {
  register,
  login,
  getProfile,
  updateProfile,
  changePassword,
  getPendingUsers,
  getAllUsers,
  updateUserStatus,
  updateUserRole
};
