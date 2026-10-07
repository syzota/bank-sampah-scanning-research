CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE auth_users (
  id TEXT PRIMARY KEY, email TEXT NOT NULL UNIQUE COLLATE NOCASE,
  password_hash TEXT NOT NULL
);
CREATE TABLE profiles (
  id TEXT PRIMARY KEY, auth_user_id TEXT NOT NULL UNIQUE REFERENCES auth_users(id) ON DELETE CASCADE,
  nama_lengkap TEXT NOT NULL, no_hp TEXT, role TEXT NOT NULL DEFAULT 'pengelola',
  is_verified INTEGER NOT NULL DEFAULT 0, bank_sampah_pilihan TEXT NOT NULL DEFAULT '[]',
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE bank_sampah (
  id TEXT PRIMARY KEY, nama TEXT NOT NULL, alamat TEXT, rt TEXT, rw TEXT,
  jam_operasional TEXT, latitude REAL, longitude REAL,
  is_active INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE pengelola_bank_sampah (
  id TEXT PRIMARY KEY, profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  bank_sampah_id TEXT NOT NULL REFERENCES bank_sampah(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL, UNIQUE(profile_id, bank_sampah_id)
);
CREATE TABLE kategori_sampah (
  id TEXT PRIMARY KEY, nama TEXT NOT NULL, deskripsi TEXT,
  urutan INTEGER NOT NULL DEFAULT 0, is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE sub_kategori_sampah (
  id TEXT PRIMARY KEY, kategori_id TEXT NOT NULL REFERENCES kategori_sampah(id),
  nama TEXT NOT NULL, deskripsi TEXT, urutan INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE tipe_sampah (
  id TEXT PRIMARY KEY, sub_kategori_id TEXT NOT NULL REFERENCES sub_kategori_sampah(id),
  nama TEXT NOT NULL, deskripsi TEXT, urutan INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE satuan (
  id TEXT PRIMARY KEY, nama TEXT NOT NULL, singkatan TEXT NOT NULL,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE jenis_sampah (
  id TEXT PRIMARY KEY, kategori_id TEXT REFERENCES kategori_sampah(id),
  sub_kategori_id TEXT REFERENCES sub_kategori_sampah(id), tipe_id TEXT REFERENCES tipe_sampah(id),
  nama TEXT NOT NULL, model_label TEXT UNIQUE, deskripsi TEXT,
  satuan_default_id TEXT REFERENCES satuan(id), urutan INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE harga_sampah (
  id TEXT PRIMARY KEY, bank_sampah_id TEXT NOT NULL REFERENCES bank_sampah(id) ON DELETE CASCADE,
  kategori_id TEXT REFERENCES kategori_sampah(id), sub_kategori_id TEXT REFERENCES sub_kategori_sampah(id),
  tipe_id TEXT REFERENCES tipe_sampah(id), jenis_sampah_id TEXT REFERENCES jenis_sampah(id),
  harga_per_satuan REAL NOT NULL CHECK(harga_per_satuan >= 0),
  satuan_id TEXT NOT NULL REFERENCES satuan(id), updated_at TEXT NOT NULL
);
CREATE TABLE pengelolaan_sampah (
  id TEXT PRIMARY KEY, bank_sampah_id TEXT NOT NULL REFERENCES bank_sampah(id),
  profile_id TEXT NOT NULL REFERENCES profiles(id), kategori_id TEXT NOT NULL REFERENCES kategori_sampah(id),
  sub_kategori_id TEXT REFERENCES sub_kategori_sampah(id), tipe_id TEXT REFERENCES tipe_sampah(id),
  jenis_sampah_id TEXT REFERENCES jenis_sampah(id), jumlah REAL NOT NULL CHECK(jumlah > 0),
  satuan_id TEXT NOT NULL REFERENCES satuan(id), harga_per_satuan REAL, total_harga REAL,
  tanggal_pengelolaan TEXT NOT NULL, catatan TEXT, nama_nasabah TEXT,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE penjualan_sampah (
  id TEXT PRIMARY KEY, bank_sampah_id TEXT NOT NULL REFERENCES bank_sampah(id),
  profile_id TEXT NOT NULL REFERENCES profiles(id), kategori_id TEXT NOT NULL REFERENCES kategori_sampah(id),
  jenis_sampah_id TEXT REFERENCES jenis_sampah(id), jumlah REAL NOT NULL,
  satuan_id TEXT NOT NULL REFERENCES satuan(id), harga_jual_per_satuan REAL NOT NULL,
  total_pendapatan REAL NOT NULL, tanggal_penjualan TEXT NOT NULL,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE hasil_scan (
  id TEXT PRIMARY KEY, transaction_id TEXT REFERENCES pengelolaan_sampah(id) ON DELETE SET NULL,
  image_path TEXT NOT NULL, image_sha256 TEXT NOT NULL, source TEXT NOT NULL,
  model_name TEXT NOT NULL, model_sha256 TEXT NOT NULL, preprocessing TEXT NOT NULL,
  seed_version TEXT NOT NULL, cpu_threads INTEGER NOT NULL,
  raw_label TEXT, raw_scores TEXT, confidence REAL,
  preprocessing_ms REAL, inference_ms REAL, total_ms REAL, model_load_ms REAL,
  scan_order INTEGER NOT NULL, device_id TEXT NOT NULL,
  device_label TEXT NOT NULL, os_version TEXT NOT NULL, app_version TEXT NOT NULL,
  is_cold_start INTEGER NOT NULL,
  test_image_id TEXT, ground_truth_label TEXT, final_label TEXT,
  status TEXT NOT NULL, error_message TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE INDEX idx_transaction_bank_date ON pengelolaan_sampah(bank_sampah_id, tanggal_pengelolaan);
CREATE INDEX idx_scan_created ON hasil_scan(created_at);
CREATE VIEW v_laporan_bulanan AS
  SELECT CAST(strftime('%Y', p.tanggal_pengelolaan) AS INTEGER) AS tahun,
    CAST(strftime('%m', p.tanggal_pengelolaan) AS INTEGER) AS bulan,
    p.bank_sampah_id, p.kategori_id, p.sub_kategori_id, p.jenis_sampah_id,
    SUM(p.jumlah) AS total_jumlah, b.nama AS bank_sampah_nama,
    k.nama AS kategori_nama, sk.nama AS sub_kategori_nama, j.nama AS jenis_sampah_nama,
    s.singkatan AS satuan
  FROM pengelolaan_sampah p
  JOIN bank_sampah b ON b.id = p.bank_sampah_id
  JOIN kategori_sampah k ON k.id = p.kategori_id
  LEFT JOIN sub_kategori_sampah sk ON sk.id = p.sub_kategori_id
  LEFT JOIN jenis_sampah j ON j.id = p.jenis_sampah_id
  JOIN satuan s ON s.id = p.satuan_id
  GROUP BY tahun, bulan, p.bank_sampah_id, p.kategori_id, p.sub_kategori_id, p.jenis_sampah_id, p.satuan_id;
CREATE VIEW v_ringkasan_tahunan AS
  SELECT CAST(strftime('%Y', tanggal_pengelolaan) AS INTEGER) AS tahun,
    CAST(strftime('%m', tanggal_pengelolaan) AS INTEGER) AS bulan,
    SUM(jumlah) AS total_jumlah
  FROM pengelolaan_sampah GROUP BY tahun, bulan;
