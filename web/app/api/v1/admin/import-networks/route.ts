import { NextRequest, NextResponse } from 'next/server';
import { importCSV } from '@/lib/places/csvImporter';

export async function POST(request: NextRequest) {
  try {
    // Basic admin check (in production, use proper authentication)
    const authHeader = request.headers.get('authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    // For now, accept any Bearer token (in production, validate JWT)
    // TODO: Implement proper admin authentication

    const contentType = request.headers.get('content-type') || '';

    if (!contentType.includes('multipart/form-data')) {
      return NextResponse.json(
        { error: 'Content-Type must be multipart/form-data' },
        { status: 400 }
      );
    }

    const formData = await request.formData();
    const file = formData.get('file') as File;
    const networkId = formData.get('networkId') as string;
    const networkName = formData.get('networkName') as string;

    if (!file) {
      return NextResponse.json(
        { error: 'File is required' },
        { status: 400 }
      );
    }

    if (!networkId || !networkName) {
      return NextResponse.json(
        { error: 'networkId and networkName are required' },
        { status: 400 }
      );
    }

    if (!file.name.toLowerCase().endsWith('.csv')) {
      return NextResponse.json(
        { error: 'File must be a CSV file' },
        { status: 400 }
      );
    }

    // Read file content
    const csvContent = await file.text();

    // Import the CSV
    const result = importCSV(csvContent, networkId, networkName);

    if (!result.success) {
      return NextResponse.json({
        success: false,
        errors: result.errors,
        imported: 0
      }, { status: 400 });
    }

    return NextResponse.json({
      success: true,
      message: `Successfully imported ${result.imported} locations for network "${networkName}"`,
      imported: result.imported,
      errors: result.errors
    });

  } catch (error) {
    console.error('Import networks error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
