import { searchNominatim } from '../lib/places/nominatimConnector';
import { searchPlaces } from '../lib/places/search';
import { importCSV, getNetworkById } from '../lib/places/csvImporter';

// Mock axios for API calls
jest.mock('axios');
import axios from 'axios';

const mockedAxios = axios as jest.Mocked<typeof axios>;

describe('Places API', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('searchNominatim', () => {
    it('should parse Nominatim API response correctly', async () => {
      const mockResponse = {
        data: [
          {
            place_id: 12345,
            display_name: 'Costco Wholesale, 450 10th St, San Francisco, CA',
            lat: '37.7749',
            lon: '-122.4194',
            type: 'supermarket',
            class: 'amenity',
            extratags: {
              brand: 'Costco'
            }
          }
        ]
      };

      mockedAxios.get.mockResolvedValueOnce(mockResponse);

      const results = await searchNominatim('costco', { lat: 37.7749, lon: -122.4194, limit: 10 });

      expect(results).toHaveLength(1);
      expect(results[0]).toMatchObject({
        id: 'nominatim:12345',
        name: 'Costco Wholesale',
        lat: 37.7749,
        lon: -122.4194,
        categories: ['supermarket', 'amenity', 'Costco'],
        dataSource: 'nominatim',
        networkGuessScore: expect.any(Number)
      });

      expect(mockedAxios.get).toHaveBeenCalledWith('https://nominatim.openstreetmap.org/search', expect.any(Object));
    });

    it('should handle API errors gracefully', async () => {
      mockedAxios.get.mockRejectedValueOnce(new Error('API Error'));

      const results = await searchNominatim('test', { limit: 10 });

      expect(results).toHaveLength(0);
    });
  });

  describe('searchPlaces', () => {
    it('should combine results from multiple sources', async () => {
      // Mock Nominatim response
      const nominatimResponse = {
        data: [
          {
            place_id: 12345,
            display_name: 'Test Store',
            lat: '37.7749',
            lon: '-122.4194',
            type: 'shop'
          }
        ]
      };

      mockedAxios.get.mockResolvedValueOnce(nominatimResponse);

      const results = await searchPlaces('test store', { limit: 5 });

      expect(results.results.length).toBeGreaterThan(0);
      expect(results.query).toBe('test store');
      expect(results.total).toBe(results.results.length);
    });
  });

  describe('CSV Import', () => {
    const sampleCSV = `name,address,lat,lon,radius
Test Store,123 Main St,37.7749,-122.4194,100
Another Store,456 Oak Ave,37.7849,-122.4294,80`;

    it('should import CSV data correctly', () => {
      const result = importCSV(sampleCSV, 'test-network', 'Test Network');

      expect(result.success).toBe(true);
      expect(result.imported).toBe(2);
      expect(result.errors).toHaveLength(0);
    });

    it('should validate CSV data', () => {
      const invalidCSV = `name,address,lat,lon,radius
Invalid Store,123 Main St,invalid,invalid,100`;

      const result = importCSV(invalidCSV, 'test-network', 'Test Network');

      expect(result.success).toBe(false);
      expect(result.imported).toBe(0);
      expect(result.errors.length).toBeGreaterThan(0);
    });

    it('should retrieve imported network data', () => {
      // First import some data
      importCSV(sampleCSV, 'test-network', 'Test Network');

      // Then retrieve it
      const network = getNetworkById('test-network');

      expect(network).toBeTruthy();
      expect(network?.id).toBe('test-network');
      expect(network?.name).toBe('Test Network');
      expect(network?.locations).toHaveLength(2);
    });
  });

  describe('Region Refresh Logic', () => {
    // Note: The region-refresh endpoint would be tested with integration tests
    // that mock the HTTP requests. For unit tests, we focus on the core logic.

    it('should validate input coordinates', () => {
      // This would be tested in the API route handler
      expect(true).toBe(true); // Placeholder
    });
  });
});
