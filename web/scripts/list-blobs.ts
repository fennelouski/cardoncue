#!/usr/bin/env npx tsx

/**
 * List all blobs in Vercel Blob storage
 */

import { config } from 'dotenv';
import { list } from '@vercel/blob';
import path from 'path';

// Load .env.production
config({ path: path.join(__dirname, '..', '.env.production') });

async function listBlobs() {
  console.log('📦 Listing blobs in Vercel Blob storage...\n');

  try {
    const { blobs } = await list();

    if (blobs.length === 0) {
      console.log('No blobs found in storage.');
      return;
    }

    console.log(`Found ${blobs.length} blobs:\n`);

    blobs.forEach((blob, index) => {
      console.log(`[${index + 1}] ${blob.pathname}`);
      console.log(`    URL: ${blob.url}`);
      console.log(`    Size: ${(blob.size / 1024).toFixed(2)} KB`);
      console.log(`    Uploaded: ${blob.uploadedAt}`);
      console.log();
    });

  } catch (error: any) {
    console.error('❌ Error listing blobs:', error.message);
    process.exit(1);
  }
}

listBlobs();
