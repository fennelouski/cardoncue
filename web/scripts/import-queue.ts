#!/usr/bin/env tsx

/**
 * CardOnCue Location Import Queue
 *
 * Comprehensive list of 100+ brands/networks to import from OpenStreetMap
 * Organized by category with network IDs
 *
 * Run: npx tsx scripts/import-queue.ts
 */

import { sql } from '@vercel/postgres';
import { batchImportBrands } from '@/lib/data-sources/unified-location-import';

// Define brand categories and their networks
const IMPORT_QUEUE = {
  // Warehouse Clubs (3)
  warehouseClubs: [
    { name: 'Costco', category: 'membership' },
    { name: "Sam's Club", category: 'membership' },
    { name: "BJ's Wholesale Club", category: 'membership' },
  ],

  // Gyms & Fitness Centers (30+)
  gyms: [
    { name: 'Planet Fitness', category: 'gym' },
    { name: 'LA Fitness', category: 'gym' },
    { name: '24 Hour Fitness', category: 'gym' },
    { name: 'Anytime Fitness', category: 'gym' },
    { name: 'Crunch Fitness', category: 'gym' },
    { name: 'Equinox', category: 'gym' },
    { name: "Gold's Gym", category: 'gym' },
    { name: 'Lifetime Fitness', category: 'gym' },
    { name: 'YMCA', category: 'gym' },
    { name: 'Orangetheory Fitness', category: 'gym' },
    { name: 'CrossFit', category: 'gym' },
    { name: 'Pure Barre', category: 'gym' },
    { name: 'SoulCycle', category: 'gym' },
    { name: 'Barry\'s Bootcamp', category: 'gym' },
    { name: 'Flywheel Sports', category: 'gym' },
    { name: 'CorePower Yoga', category: 'gym' },
    { name: 'Yoga Works', category: 'gym' },
    { name: 'Club Pilates', category: 'gym' },
    { name: 'Snap Fitness', category: 'gym' },
    { name: 'Retro Fitness', category: 'gym' },
    { name: 'Youfit Health Clubs', category: 'gym' },
    { name: 'Workout Anytime', category: 'gym' },
    { name: 'Powerhouse Gym', category: 'gym' },
    { name: 'EoS Fitness', category: 'gym' },
    { name: 'Vasa Fitness', category: 'gym' },
    { name: 'Mountainside Fitness', category: 'gym' },
    { name: 'OneLife Fitness', category: 'gym' },
    { name: 'UFC Gym', category: 'gym' },
    { name: 'Blink Fitness', category: 'gym' },
    { name: 'Esporta Fitness', category: 'gym' },
  ],

  // Grocery Stores with Loyalty Programs (25+)
  groceryStores: [
    { name: 'Kroger', category: 'loyalty' },
    { name: 'Safeway', category: 'loyalty' },
    { name: 'Albertsons', category: 'loyalty' },
    { name: 'Publix', category: 'loyalty' },
    { name: 'Whole Foods Market', category: 'loyalty' },
    { name: 'Trader Joe\'s', category: 'loyalty' },
    { name: 'H-E-B', category: 'loyalty' },
    { name: 'Wegmans', category: 'loyalty' },
    { name: 'Giant Food', category: 'loyalty' },
    { name: 'Stop & Shop', category: 'loyalty' },
    { name: 'Food Lion', category: 'loyalty' },
    { name: 'Harris Teeter', category: 'loyalty' },
    { name: 'Hy-Vee', category: 'loyalty' },
    { name: 'Meijer', category: 'loyalty' },
    { name: 'ShopRite', category: 'loyalty' },
    { name: 'Winn-Dixie', category: 'loyalty' },
    { name: 'Ralphs', category: 'loyalty' },
    { name: 'Fred Meyer', category: 'loyalty' },
    { name: 'King Soopers', category: 'loyalty' },
    { name: 'Fry\'s Food', category: 'loyalty' },
    { name: 'Smith\'s Food and Drug', category: 'loyalty' },
    { name: 'QFC', category: 'loyalty' },
    { name: 'Dillons', category: 'loyalty' },
    { name: 'Baker\'s', category: 'loyalty' },
    { name: 'Gerbes', category: 'loyalty' },
  ],

  // Pharmacies (5)
  pharmacies: [
    { name: 'CVS Pharmacy', category: 'loyalty' },
    { name: 'Walgreens', category: 'loyalty' },
    { name: 'Rite Aid', category: 'loyalty' },
    { name: 'Walmart Pharmacy', category: 'loyalty' },
    { name: 'Target Pharmacy', category: 'loyalty' },
  ],

  // Retail Stores with Loyalty Programs (15+)
  retail: [
    { name: 'Target', category: 'loyalty' },
    { name: 'Best Buy', category: 'loyalty' },
    { name: 'Staples', category: 'loyalty' },
    { name: 'Office Depot', category: 'loyalty' },
    { name: 'PetSmart', category: 'loyalty' },
    { name: 'Petco', category: 'loyalty' },
    { name: 'REI', category: 'membership' },
    { name: 'Dick\'s Sporting Goods', category: 'loyalty' },
    { name: 'Sports Authority', category: 'loyalty' },
    { name: 'Bed Bath & Beyond', category: 'loyalty' },
    { name: 'Container Store', category: 'loyalty' },
    { name: 'Barnes & Noble', category: 'loyalty' },
    { name: 'GameStop', category: 'loyalty' },
    { name: 'Michaels', category: 'loyalty' },
    { name: 'Jo-Ann Fabric', category: 'loyalty' },
  ],

  // Coffee Shops (5+)
  coffeeShops: [
    { name: 'Starbucks', category: 'loyalty' },
    { name: 'Dunkin\'', category: 'loyalty' },
    { name: 'Peet\'s Coffee', category: 'loyalty' },
    { name: 'The Coffee Bean & Tea Leaf', category: 'loyalty' },
    { name: 'Caribou Coffee', category: 'loyalty' },
  ],

  // Fast Food / Quick Service (10+)
  fastFood: [
    { name: 'Panera Bread', category: 'loyalty' },
    { name: 'Chipotle', category: 'loyalty' },
    { name: 'Subway', category: 'loyalty' },
    { name: 'McDonald\'s', category: 'loyalty' },
    { name: 'Chick-fil-A', category: 'loyalty' },
    { name: 'Taco Bell', category: 'loyalty' },
    { name: 'Wendy\'s', category: 'loyalty' },
    { name: 'Burger King', category: 'loyalty' },
    { name: 'Arby\'s', category: 'loyalty' },
    { name: 'Jersey Mike\'s', category: 'loyalty' },
  ],

  // Gas Stations (8+)
  gasStations: [
    { name: 'Shell', category: 'loyalty' },
    { name: 'BP', category: 'loyalty' },
    { name: 'Chevron', category: 'loyalty' },
    { name: 'ExxonMobil', category: 'loyalty' },
    { name: '76', category: 'loyalty' },
    { name: 'Circle K', category: 'loyalty' },
    { name: '7-Eleven', category: 'loyalty' },
    { name: 'Speedway', category: 'loyalty' },
  ],

  // Movie Theaters (5+)
  movieTheaters: [
    { name: 'AMC Theatres', category: 'loyalty' },
    { name: 'Regal Cinemas', category: 'loyalty' },
    { name: 'Cinemark', category: 'loyalty' },
    { name: 'Alamo Drafthouse', category: 'loyalty' },
    { name: 'Arclight Cinemas', category: 'loyalty' },
  ],

  // Libraries (generic - will map to local library systems)
  libraries: [
    { name: 'Public Library', category: 'library' },
  ],
};

/**
 * Flatten all brands into a single queue
 */
function getAllBrands() {
  const allBrands: Array<{ name: string; category: string; priority: number }> = [];
  let priority = 1;

  // High priority: Warehouse clubs (most common membership cards)
  IMPORT_QUEUE.warehouseClubs.forEach(brand => {
    allBrands.push({ ...brand, priority: priority++ });
  });

  // High priority: Gyms (very common)
  IMPORT_QUEUE.gyms.forEach(brand => {
    allBrands.push({ ...brand, priority: priority++ });
  });

  // Medium priority: Grocery stores
  IMPORT_QUEUE.groceryStores.forEach(brand => {
    allBrands.push({ ...brand, priority: priority++ });
  });

  // Medium priority: Pharmacies
  IMPORT_QUEUE.pharmacies.forEach(brand => {
    allBrands.push({ ...brand, priority: priority++ });
  });

  // Lower priority: Retail, coffee, etc.
  IMPORT_QUEUE.retail.forEach(brand => {
    allBrands.push({ ...brand, priority: priority++ });
  });
  IMPORT_QUEUE.coffeeShops.forEach(brand => {
    allBrands.push({ ...brand, priority: priority++ });
  });
  IMPORT_QUEUE.fastFood.forEach(brand => {
    allBrands.push({ ...brand, priority: priority++ });
  });
  IMPORT_QUEUE.gasStations.forEach(brand => {
    allBrands.push({ ...brand, priority: priority++ });
  });
  IMPORT_QUEUE.movieTheaters.forEach(brand => {
    allBrands.push({ ...brand, priority: priority++ });
  });

  // Libraries
  IMPORT_QUEUE.libraries.forEach(brand => {
    allBrands.push({ ...brand, priority: priority++ });
  });

  return allBrands;
}

/**
 * Create or get network IDs for all brands
 */
async function ensureNetworksExist() {
  const allBrands = getAllBrands();
  const brandsWithNetworkIds: Array<{ name: string; networkId: string }> = [];

  console.log(`\n🔍 Ensuring ${allBrands.length} networks exist in database...\n`);

  for (const brand of allBrands) {
    try {
      // Check if network exists
      const existing = await sql`
        SELECT id FROM networks
        WHERE LOWER(name) = LOWER(${brand.name})
      `;

      let networkId: string;

      if (existing.rows.length > 0) {
        networkId = existing.rows[0].id;
        console.log(`  ✓ Found existing: ${brand.name} (${networkId})`);
      } else {
        // Create new network
        const result = await sql`
          INSERT INTO networks (name, category, logo_url)
          VALUES (${brand.name}, ${brand.category}, null)
          RETURNING id
        `;
        networkId = result.rows[0].id;
        console.log(`  + Created new: ${brand.name} (${networkId})`);
      }

      brandsWithNetworkIds.push({
        name: brand.name,
        networkId
      });

    } catch (error) {
      console.error(`  ✗ Error with ${brand.name}:`, error);
    }
  }

  console.log(`\n✅ Processed ${brandsWithNetworkIds.length} networks\n`);
  return brandsWithNetworkIds;
}

/**
 * Save import queue to JSON file for reference
 */
function saveQueueToFile(brands: Array<{ name: string; networkId: string }>) {
  const fs = require('fs');
  const path = require('path');

  const queueData = {
    generated: new Date().toISOString(),
    totalBrands: brands.length,
    brands: brands.map((b, i) => ({
      priority: i + 1,
      name: b.name,
      networkId: b.networkId
    }))
  };

  const filePath = path.join(__dirname, 'import-queue.json');
  fs.writeFileSync(filePath, JSON.stringify(queueData, null, 2));

  console.log(`📝 Saved import queue to: ${filePath}\n`);
  return filePath;
}

/**
 * Main execution
 */
async function main() {
  console.log('🚀 CardOnCue Location Import Queue Generator\n');
  console.log('=' .repeat(60));

  // Count brands by category
  const allBrands = getAllBrands();
  console.log(`\n📊 Queue Summary:`);
  console.log(`   Warehouse Clubs: ${IMPORT_QUEUE.warehouseClubs.length}`);
  console.log(`   Gyms & Fitness: ${IMPORT_QUEUE.gyms.length}`);
  console.log(`   Grocery Stores: ${IMPORT_QUEUE.groceryStores.length}`);
  console.log(`   Pharmacies: ${IMPORT_QUEUE.pharmacies.length}`);
  console.log(`   Retail Stores: ${IMPORT_QUEUE.retail.length}`);
  console.log(`   Coffee Shops: ${IMPORT_QUEUE.coffeeShops.length}`);
  console.log(`   Fast Food: ${IMPORT_QUEUE.fastFood.length}`);
  console.log(`   Gas Stations: ${IMPORT_QUEUE.gasStations.length}`);
  console.log(`   Movie Theaters: ${IMPORT_QUEUE.movieTheaters.length}`);
  console.log(`   Libraries: ${IMPORT_QUEUE.libraries.length}`);
  console.log(`   ` + '-'.repeat(40));
  console.log(`   TOTAL: ${allBrands.length} brands\n`);

  // Ensure all networks exist in database
  const brandsWithNetworkIds = await ensureNetworksExist();

  // Save queue to JSON file
  const queueFilePath = saveQueueToFile(brandsWithNetworkIds);

  console.log('✅ Import queue is ready!\n');
  console.log('📋 Next steps:');
  console.log('   1. Review the queue: cat scripts/import-queue.json');
  console.log('   2. Run batch import for a city (e.g., Los Angeles):');
  console.log('      curl -X POST https://cardoncue.com/api/v1/admin/import-locations \\');
  console.log('        -H "Content-Type: application/json" \\');
  console.log('        -d @scripts/import-queue.json\n');

  console.log('💡 Or import programmatically:');
  console.log('   const queue = require("./scripts/import-queue.json");');
  console.log('   await batchImportBrands(queue.brands, lat, lon, radiusKm);\n');

  process.exit(0);
}

// Run if executed directly
if (require.main === module) {
  main().catch(error => {
    console.error('❌ Error:', error);
    process.exit(1);
  });
}

export { IMPORT_QUEUE, getAllBrands, ensureNetworksExist };
