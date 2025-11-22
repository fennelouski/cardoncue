#!/usr/bin/env node

/**
 * CSV Importer for CardOnCue location data
 *
 * Usage:
 *   node import.js <network-id> <csv-file>
 *
 * Example:
 *   node import.js costco costco-locations.csv
 */

const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');

// Parse CSV (simple implementation)
function parseCSV(content) {
  const lines = content.trim().split('\n');
  const headers = lines[0].split(',').map(h => h.trim());

  const rows = [];
  for (let i = 1; i < lines.length; i++) {
    const values = lines[i].split(',').map(v => v.trim());
    const row = {};
    headers.forEach((header, index) => {
      row[header] = values[index];
    });
    rows.push(row);
  }

  return rows;
}

// Main import function
async function importLocations(networkId, csvPath) {
  console.log(`Importing locations for network: ${networkId}`);
  console.log(`Reading CSV: ${csvPath}`);

  const csvContent = fs.readFileSync(csvPath, 'utf-8');
  const rows = parseCSV(csvContent);

  console.log(`Found ${rows.length} locations to import\n`);

  const locations = rows.map((row, index) => {
    const location = {
      id: `loc_${networkId}_${String(index + 1).padStart(3, '0')}`,
      network_id: networkId,
      name: row.name,
      address: row.address,
      lat: parseFloat(row.lat),
      lon: parseFloat(row.lon),
      radius_meters: parseInt(row.radius) || 100,
      phone: row.phone || null,
    };

    console.log(`✅ ${location.id}: ${location.name}`);
    return location;
  });

  // Generate SQL insert statements
  console.log('\n--- SQL INSERT STATEMENTS ---\n');

  locations.forEach(loc => {
    const sql = `INSERT INTO locations (id, network_id, name, address, lat, lon, radius_meters, phone) VALUES ('${loc.id}', '${loc.network_id}', '${loc.name}', '${loc.address}', ${loc.lat}, ${loc.lon}, ${loc.radius_meters}, ${loc.phone ? "'" + loc.phone + "'" : 'NULL'});`;
    console.log(sql);
  });

  // Generate JSON output
  const outputPath = path.join(__dirname, `${networkId}-locations.json`);
  fs.writeFileSync(outputPath, JSON.stringify(locations, null, 2));
  console.log(`\n✅ JSON output written to: ${outputPath}`);

  return locations;
}

// Import networks from CSV
function importNetworks(csvPath) {
  console.log(`Importing networks from: ${csvPath}\n`);

  const csvContent = fs.readFileSync(csvPath, 'utf-8');
  const rows = parseCSV(csvContent);

  console.log(`Found ${rows.length} networks to import\n`);

  const networks = rows.map(row => {
    const network = {
      id: row.id,
      name: row.name,
      canonical_names: row.canonical_names.split('|'),
      category: row.category,
      is_large_area: row.is_large_area === 'true',
      default_radius_meters: parseInt(row.default_radius_meters),
      tags: row.tags.split(','),
    };

    console.log(`✅ ${network.id}: ${network.name}`);
    return network;
  });

  // Generate SQL insert statements
  console.log('\n--- SQL INSERT STATEMENTS ---\n');

  networks.forEach(net => {
    const sql = `INSERT INTO networks (id, name, canonical_names, category, is_large_area, default_radius_meters, tags) VALUES ('${net.id}', '${net.name}', '${JSON.stringify(net.canonical_names)}', '${net.category}', ${net.is_large_area}, ${net.default_radius_meters}, '${JSON.stringify(net.tags)}');`;
    console.log(sql);
  });

  // Generate JSON output
  const outputPath = path.join(__dirname, 'networks.json');
  fs.writeFileSync(outputPath, JSON.stringify(networks, null, 2));
  console.log(`\n✅ JSON output written to: ${outputPath}`);

  return networks;
}

// Run importer
const args = process.argv.slice(2);

if (args.length === 0) {
  console.log('Usage:');
  console.log('  Import locations: node import.js <network-id> <csv-file>');
  console.log('  Import networks:  node import.js networks <csv-file>');
  console.log('\nExamples:');
  console.log('  node import.js costco costco-locations.csv');
  console.log('  node import.js networks sample-networks.csv');
  process.exit(1);
}

if (args[0] === 'networks') {
  const csvPath = path.join(__dirname, args[1]);
  importNetworks(csvPath);
} else {
  const networkId = args[0];
  const csvPath = path.join(__dirname, args[1]);
  importLocations(networkId, csvPath);
}
