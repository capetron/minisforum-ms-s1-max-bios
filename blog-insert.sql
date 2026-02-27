-- Insert blog post into petronellatech.com Blog.sqlite
-- Run on production: sqlite3 Blog.sqlite < blog-insert.sql
-- Category 6 = Technology
PRAGMA busy_timeout = 30000;

INSERT INTO stories (title, url, html, text, desc, date, categoryID, icon, author)
VALUES (
  'How to Update Your Minisforum MS-S1 Max BIOS for AI Workloads — Without Windows',
  'minisforum-ms-s1-max-bios-update-linux',
  readfile('blog-post.html'),
  'Update the BIOS on your Minisforum MS-S1 Max from Linux using EFI Shell. No Windows required. Step-by-step guide for NixOS, Ubuntu, Arch, and other Linux distributions. Covers the AMD Ryzen AI Max+ 395 workstation with 128GB RAM.',
  'Update your Minisforum MS-S1 Max BIOS from Linux using EFI Shell — no Windows needed. Full step-by-step guide with automation script.',
  datetime('now'),
  6,
  '',
  'Craig Petronella'
);
