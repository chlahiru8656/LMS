const express = require('express');
const cors = require('cors');
require('dotenv').config();

const authRoutes = require('./routes/authRoutes');
const academicRoutes = require('./routes/academicRoutes');
const bookingRoutes = require('./routes/bookingRoutes');
const equipmentRoutes = require('./routes/equipmentRoutes');
const consumableRoutes = require('./routes/consumableRoutes');
const cleaningRoutes = require('./routes/cleaningRoutes');
const dashboardRoutes = require('./routes/dashboardRoutes');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Static files (for uploaded lab sheets, equipment images, etc.)
app.use('/uploads', express.static('uploads'));

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', message: 'LMS BML API is running', timestamp: new Date().toISOString() });
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/academic', academicRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/equipment', equipmentRoutes);
app.use('/api/consumables', consumableRoutes);
app.use('/api/cleaning', cleaningRoutes);
app.use('/api/dashboard', dashboardRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ message: 'Route not found.' });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ message: 'Internal server error.' });
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`\n=================================`);
  console.log(`  LMS BML API Server`);
  console.log(`  Running on port ${PORT}`);
  console.log(`  http://localhost:${PORT}`);
  console.log(`=================================\n`);
});

module.exports = app;
