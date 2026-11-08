const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

async function seed() {
  console.log('\n🚀 LMS BML Database Setup\n');

  // Connect without database first to create it
  const rootConnection = await mysql.createConnection({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    multipleStatements: true
  });

  try {
    // Read and execute schema
    console.log('📦 Creating database and tables...');
    const schemaPath = path.join(__dirname, '..', '..', 'database', 'schema.sql');
    const schema = fs.readFileSync(schemaPath, 'utf8');
    await rootConnection.query(schema);
    console.log('✅ Database and tables created successfully.\n');
  } catch (error) {
    if (error.code === 'ER_TABLE_EXISTS_ERROR') {
      console.log('ℹ️  Tables already exist. Skipping schema creation.\n');
    } else {
      throw error;
    }
  } finally {
    await rootConnection.end();
  }

  // Now connect to the database
  const pool = require('./config/db');

  try {
    // Create Master Admin user
    console.log('👤 Creating Master Admin user...');
    const adminEmail = 'admin@lms.usjp.ac.lk';
    const adminPassword = 'admin123';

    const [existing] = await pool.query('SELECT id FROM users WHERE email = ?', [adminEmail]);
    if (existing.length > 0) {
      console.log('ℹ️  Master Admin already exists. Skipping.\n');
    } else {
      const salt = await bcrypt.genSalt(10);
      const hash = await bcrypt.hash(adminPassword, salt);

      await pool.query(
        `INSERT INTO users (name, email, password_hash, role, student_staff_id, status) 
         VALUES (?, ?, ?, 'master_admin', ?, 'approved')`,
        ['System Administrator', adminEmail, hash, 'ADMIN001']
      );
      console.log('✅ Master Admin created.');
      console.log(`   Email:    ${adminEmail}`);
      console.log(`   Password: ${adminPassword}`);
      console.log('   ⚠️  Change this password after first login!\n');
    }

    // Create sample staff users for testing
    console.log('👥 Creating sample staff users...');
    const staffUsers = [
      { name: 'Dr. Lab Incharge', email: 'incharge@lms.usjp.ac.lk', role: 'lab_incharge', sid: 'STAFF001' },
      { name: 'Mr. Technical Officer', email: 'to@lms.usjp.ac.lk', role: 'lab_to', sid: 'STAFF002' },
      { name: 'Mr. Lab Assistant', email: 'assistant@lms.usjp.ac.lk', role: 'lab_assistant', sid: 'STAFF003' },
      { name: 'Dr. Course Coordinator', email: 'coordinator@lms.usjp.ac.lk', role: 'course_coordinator', sid: 'STAFF004' },
      { name: 'Ms. Instructor', email: 'instructor@lms.usjp.ac.lk', role: 'instructor', sid: 'STAFF005' }
    ];

    const salt = await bcrypt.genSalt(10);
    const defaultHash = await bcrypt.hash('password123', salt);

    for (const user of staffUsers) {
      const [exists] = await pool.query('SELECT id FROM users WHERE email = ?', [user.email]);
      if (exists.length === 0) {
        await pool.query(
          `INSERT INTO users (name, email, password_hash, role, student_staff_id, status) 
           VALUES (?, ?, ?, ?, ?, 'approved')`,
          [user.name, user.email, defaultHash, user.role, user.sid]
        );
        console.log(`   ✅ ${user.role}: ${user.email} (password: password123)`);
      } else {
        console.log(`   ℹ️  ${user.role} already exists. Skipping.`);
      }
    }

    // Create sample students
    console.log('\n🎓 Creating sample students...');
    const students = [
      { name: 'Kasun Perera', email: 'kasun@students.usjp.ac.lk', sid: '23/ENG001' },
      { name: 'Nimal Silva', email: 'nimal@students.usjp.ac.lk', sid: '23/ENG002' },
      { name: 'Amaya Fernando', email: 'amaya@students.usjp.ac.lk', sid: '23/ENG003' },
      { name: 'Dilshan Rajapaksa', email: 'dilshan@students.usjp.ac.lk', sid: '23/ENG004' },
      { name: 'Sachini Weerasinghe', email: 'sachini@students.usjp.ac.lk', sid: '23/ENG005' }
    ];

    const studentHash = await bcrypt.hash('student123', salt);
    for (const student of students) {
      const [exists] = await pool.query('SELECT id FROM users WHERE email = ?', [student.email]);
      if (exists.length === 0) {
        await pool.query(
          `INSERT INTO users (name, email, password_hash, role, student_staff_id, status) 
           VALUES (?, ?, ?, 'student', ?, 'approved')`,
          [student.name, student.email, studentHash, student.sid]
        );
        console.log(`   ✅ ${student.name} (${student.sid})`);
      }
    }

    // Create sample academic data
    console.log('\n📚 Creating sample academic data...');

    // Batch
    const [batchExists] = await pool.query('SELECT id FROM batches WHERE year = 2023');
    let batchId;
    if (batchExists.length === 0) {
      const [batchResult] = await pool.query(
        'INSERT INTO batches (name, year) VALUES (?, ?)',
        ['2023 Intake', 2023]
      );
      batchId = batchResult.insertId;
      console.log('   ✅ Batch: 2023 Intake');
    } else {
      batchId = batchExists[0].id;
      console.log('   ℹ️  Batch already exists.');
    }

    // Semester
    const [semExists] = await pool.query('SELECT id FROM semesters WHERE batch_id = ? AND semester_number = 3', [batchId]);
    let semesterId;
    if (semExists.length === 0) {
      const [semResult] = await pool.query(
        'INSERT INTO semesters (batch_id, semester_number, name) VALUES (?, ?, ?)',
        [batchId, 3, 'Semester 3']
      );
      semesterId = semResult.insertId;
      console.log('   ✅ Semester: Semester 3');
    } else {
      semesterId = semExists[0].id;
    }

    // Course
    const [coordinators] = await pool.query("SELECT id FROM users WHERE role = 'course_coordinator' LIMIT 1");
    const coordId = coordinators.length > 0 ? coordinators[0].id : null;

    const [courseExists] = await pool.query('SELECT id FROM courses WHERE code = ?', ['CE2201']);
    let courseId;
    if (courseExists.length === 0) {
      const [courseResult] = await pool.query(
        'INSERT INTO courses (semester_id, code, name, coordinator_id) VALUES (?, ?, ?, ?)',
        [semesterId, 'CE2201', 'Concrete Technology', coordId]
      );
      courseId = courseResult.insertId;
      console.log('   ✅ Course: CE2201 - Concrete Technology');
    } else {
      courseId = courseExists[0].id;
    }

    // Enroll sample students in the course
    const [studentRows] = await pool.query("SELECT id FROM users WHERE role = 'student' AND status = 'approved'");
    for (const s of studentRows) {
      await pool.query(
        'INSERT IGNORE INTO course_enrollments (course_id, student_id) VALUES (?, ?)',
        [courseId, s.id]
      );
    }
    console.log(`   ✅ Enrolled ${studentRows.length} students in CE2201`);

    // Sample equipment
    console.log('\n🔧 Creating sample BML equipment...');
    const equipmentItems = [
      { name: 'Compression Testing Machine', model: 'CTM-500', serial: 'CTM-2020-001', manufacturer: 'MATEST' },
      { name: 'Digital Platform Scale', model: 'DPS-150', serial: 'DPS-2021-001', manufacturer: 'KERN' },
      { name: 'Vicat Apparatus (Digital)', model: 'VA-100', serial: 'VA-2019-001', manufacturer: 'MATEST' },
      { name: 'Water Curing Tank', model: 'WCT-1000', serial: 'WCT-2020-001', manufacturer: 'UTEST' },
      { name: 'Sieve Shaker', model: 'SS-200', serial: 'SS-2021-001', manufacturer: 'UTEST' },
      { name: 'Concrete Mixer (Pan)', model: 'PM-60L', serial: 'PM-2019-001', manufacturer: 'CONTROLS' },
      { name: 'Concrete Mixer (Drum)', model: 'DM-120L', serial: 'DM-2020-001', manufacturer: 'BELLE' },
      { name: 'Casagrande Apparatus', model: 'CA-100', serial: 'CA-2021-001', manufacturer: 'MATEST' },
      { name: 'V-Funnel Apparatus', model: 'VF-100', serial: 'VF-2022-001', manufacturer: 'MATEST' },
      { name: 'Precision Balance', model: 'PB-3000', serial: 'PB-2021-001', manufacturer: 'KERN' }
    ];

    for (const eq of equipmentItems) {
      const [exists] = await pool.query('SELECT id FROM equipment WHERE serial_number = ?', [eq.serial]);
      if (exists.length === 0) {
        await pool.query(
          'INSERT INTO equipment (lab_id, name, model, serial_number, manufacturer, status) VALUES (1, ?, ?, ?, ?, ?)',
          [eq.name, eq.model, eq.serial, eq.manufacturer, 'available']
        );
      }
    }
    console.log(`   ✅ ${equipmentItems.length} equipment items added`);

    // Sample consumables
    console.log('\n📦 Creating sample BML consumables...');
    const consumableItems = [
      { name: 'Portland Cement', category: 'Binders', unit: 'bags', stock: 20, threshold: 5 },
      { name: 'Fine Aggregate (Sand)', category: 'Aggregates', unit: 'kg', stock: 500, threshold: 100 },
      { name: 'Coarse Aggregate', category: 'Aggregates', unit: 'kg', stock: 300, threshold: 100 },
      { name: 'Chemical Admixture', category: 'Chemical', unit: 'litres', stock: 10, threshold: 2 },
      { name: 'Clay Bricks', category: 'Masonry', unit: 'pieces', stock: 100, threshold: 20 },
      { name: 'Curing Compound', category: 'Chemical', unit: 'litres', stock: 5, threshold: 1 },
      { name: 'Rubber Gloves', category: 'Safety', unit: 'pairs', stock: 30, threshold: 10 },
      { name: 'Machine Oil', category: 'Maintenance', unit: 'litres', stock: 3, threshold: 1 }
    ];

    for (const con of consumableItems) {
      const [exists] = await pool.query('SELECT id FROM consumables WHERE name = ? AND lab_id = 1', [con.name]);
      if (exists.length === 0) {
        await pool.query(
          'INSERT INTO consumables (lab_id, name, category, unit, current_stock, min_threshold) VALUES (1, ?, ?, ?, ?, ?)',
          [con.name, con.category, con.unit, con.stock, con.threshold]
        );
      }
    }
    console.log(`   ✅ ${consumableItems.length} consumable items added`);

    // Sample practical
    console.log('\n🧪 Creating sample practicals...');
    const [pracExists] = await pool.query('SELECT id FROM practicals WHERE course_id = ? AND name = ?', [courseId, 'Compressive Strength Test of Concrete Cubes']);
    if (pracExists.length === 0) {
      const [pracResult] = await pool.query(
        'INSERT INTO practicals (course_id, name, description) VALUES (?, ?, ?)',
        [courseId, 'Compressive Strength Test of Concrete Cubes', 'Determine the compressive strength of concrete cube specimens at 7 and 28 days of curing.']
      );

      // Link equipment to practical
      const [ctm] = await pool.query("SELECT id FROM equipment WHERE name = 'Compression Testing Machine' LIMIT 1");
      const [scale] = await pool.query("SELECT id FROM equipment WHERE name = 'Digital Platform Scale' LIMIT 1");
      const [mixer] = await pool.query("SELECT id FROM equipment WHERE name = 'Concrete Mixer (Pan)' LIMIT 1");

      if (ctm.length > 0) await pool.query('INSERT INTO practical_equipment (practical_id, equipment_id, quantity_needed) VALUES (?, ?, 1)', [pracResult.insertId, ctm[0].id]);
      if (scale.length > 0) await pool.query('INSERT INTO practical_equipment (practical_id, equipment_id, quantity_needed) VALUES (?, ?, 1)', [pracResult.insertId, scale[0].id]);
      if (mixer.length > 0) await pool.query('INSERT INTO practical_equipment (practical_id, equipment_id, quantity_needed) VALUES (?, ?, 1)', [pracResult.insertId, mixer[0].id]);

      // Link consumables to practical
      const [cement] = await pool.query("SELECT id FROM consumables WHERE name = 'Portland Cement' LIMIT 1");
      const [sand] = await pool.query("SELECT id FROM consumables WHERE name = 'Fine Aggregate (Sand)' LIMIT 1");
      const [coarse] = await pool.query("SELECT id FROM consumables WHERE name = 'Coarse Aggregate' LIMIT 1");

      if (cement.length > 0) await pool.query('INSERT INTO practical_materials (practical_id, consumable_id, quantity_needed) VALUES (?, ?, 2)', [pracResult.insertId, cement[0].id]);
      if (sand.length > 0) await pool.query('INSERT INTO practical_materials (practical_id, consumable_id, quantity_needed) VALUES (?, ?, 15)', [pracResult.insertId, sand[0].id]);
      if (coarse.length > 0) await pool.query('INSERT INTO practical_materials (practical_id, consumable_id, quantity_needed) VALUES (?, ?, 25)', [pracResult.insertId, coarse[0].id]);

      console.log('   ✅ Practical: Compressive Strength Test of Concrete Cubes');
    }

    console.log('\n=================================');
    console.log('  ✅ Database seeded successfully!');
    console.log('=================================');
    console.log('\n📋 Login Credentials:');
    console.log('  Master Admin:       admin@lms.usjp.ac.lk / admin123');
    console.log('  Lab Incharge:       incharge@lms.usjp.ac.lk / password123');
    console.log('  Lab TO:             to@lms.usjp.ac.lk / password123');
    console.log('  Lab Assistant:      assistant@lms.usjp.ac.lk / password123');
    console.log('  Course Coordinator: coordinator@lms.usjp.ac.lk / password123');
    console.log('  Instructor:         instructor@lms.usjp.ac.lk / password123');
    console.log('  Students:           kasun@students.usjp.ac.lk / student123');
    console.log('');

  } catch (error) {
    console.error('❌ Seed error:', error);
  } finally {
    await pool.end();
    process.exit(0);
  }
}

seed();
