import { pool } from '@/lib/db';

async function getDashboardMetrics() {
  try {
    const [brandsResult, locationsResult, templatesResult, associationsResult] = await Promise.all([
      pool.query('SELECT COUNT(*) as count FROM brands'),
      pool.query('SELECT COUNT(*) as count FROM brand_locations'),
      pool.query('SELECT COUNT(*) as count FROM card_templates'),
      pool.query('SELECT COUNT(*) as count FROM template_brand_locations'),
    ]);

    const verifiedBrands = await pool.query('SELECT COUNT(*) as count FROM brands WHERE verified = true');
    const verifiedLocations = await pool.query('SELECT COUNT(*) as count FROM brand_locations WHERE verified = true');
    const verifiedTemplates = await pool.query('SELECT COUNT(*) as count FROM card_templates WHERE verified = true');

    const recentBrands = await pool.query(
      'SELECT name, display_name, created_at FROM brands ORDER BY created_at DESC LIMIT 5'
    );

    const recentLocations = await pool.query(
      `
      SELECT l.name, l.city, l.state, l.created_at, b.display_name as brand_name
      FROM brand_locations l
      LEFT JOIN brands b ON l.brand_id = b.id
      ORDER BY l.created_at DESC LIMIT 5
      `
    );

    return {
      brands: {
        total: parseInt(brandsResult.rows[0].count),
        verified: parseInt(verifiedBrands.rows[0].count),
        recent: recentBrands.rows,
      },
      locations: {
        total: parseInt(locationsResult.rows[0].count),
        verified: parseInt(verifiedLocations.rows[0].count),
        recent: recentLocations.rows,
      },
      templates: {
        total: parseInt(templatesResult.rows[0].count),
        verified: parseInt(verifiedTemplates.rows[0].count),
      },
      associations: {
        total: parseInt(associationsResult.rows[0].count),
      },
    };
  } catch (error) {
    console.error('Error fetching dashboard metrics:', error);
    return {
      brands: { total: 0, verified: 0, recent: [] },
      locations: { total: 0, verified: 0, recent: [] },
      templates: { total: 0, verified: 0 },
      associations: { total: 0 },
    };
  }
}

export default async function AdminDashboard() {
  const metrics = await getDashboardMetrics();

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-gray-900">Dashboard</h2>
        <p className="mt-1 text-sm text-gray-500">
          Overview of your card template management system
        </p>
      </div>

      <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
        <div className="bg-white overflow-hidden shadow rounded-lg">
          <div className="p-5">
            <div className="flex items-center">
              <div className="flex-shrink-0">
                <div className="text-3xl font-bold text-indigo-600">
                  {metrics.brands.total}
                </div>
              </div>
              <div className="ml-5 w-0 flex-1">
                <dl>
                  <dt className="text-sm font-medium text-gray-500 truncate">
                    Total Brands
                  </dt>
                  <dd className="text-sm text-gray-900">
                    {metrics.brands.verified} verified
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-white overflow-hidden shadow rounded-lg">
          <div className="p-5">
            <div className="flex items-center">
              <div className="flex-shrink-0">
                <div className="text-3xl font-bold text-green-600">
                  {metrics.locations.total}
                </div>
              </div>
              <div className="ml-5 w-0 flex-1">
                <dl>
                  <dt className="text-sm font-medium text-gray-500 truncate">
                    Total Locations
                  </dt>
                  <dd className="text-sm text-gray-900">
                    {metrics.locations.verified} verified
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-white overflow-hidden shadow rounded-lg">
          <div className="p-5">
            <div className="flex items-center">
              <div className="flex-shrink-0">
                <div className="text-3xl font-bold text-purple-600">
                  {metrics.templates.total}
                </div>
              </div>
              <div className="ml-5 w-0 flex-1">
                <dl>
                  <dt className="text-sm font-medium text-gray-500 truncate">
                    Card Templates
                  </dt>
                  <dd className="text-sm text-gray-900">
                    {metrics.templates.verified} verified
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-white overflow-hidden shadow rounded-lg">
          <div className="p-5">
            <div className="flex items-center">
              <div className="flex-shrink-0">
                <div className="text-3xl font-bold text-orange-600">
                  {metrics.associations.total}
                </div>
              </div>
              <div className="ml-5 w-0 flex-1">
                <dl>
                  <dt className="text-sm font-medium text-gray-500 truncate">
                    Location Links
                  </dt>
                  <dd className="text-sm text-gray-900">
                    Template-Location associations
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <div className="bg-white shadow rounded-lg">
          <div className="px-4 py-5 sm:p-6">
            <h3 className="text-lg font-medium leading-6 text-gray-900">
              Recent Brands
            </h3>
            <div className="mt-4">
              {metrics.brands.recent.length === 0 ? (
                <p className="text-sm text-gray-500">No brands yet</p>
              ) : (
                <ul className="divide-y divide-gray-200">
                  {metrics.brands.recent.map((brand: any) => (
                    <li key={brand.name} className="py-3">
                      <div className="flex justify-between">
                        <div>
                          <p className="text-sm font-medium text-gray-900">
                            {brand.display_name}
                          </p>
                          <p className="text-sm text-gray-500">{brand.name}</p>
                        </div>
                        <div className="text-sm text-gray-500">
                          {new Date(brand.created_at).toLocaleDateString()}
                        </div>
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </div>
        </div>

        <div className="bg-white shadow rounded-lg">
          <div className="px-4 py-5 sm:p-6">
            <h3 className="text-lg font-medium leading-6 text-gray-900">
              Recent Locations
            </h3>
            <div className="mt-4">
              {metrics.locations.recent.length === 0 ? (
                <p className="text-sm text-gray-500">No locations yet</p>
              ) : (
                <ul className="divide-y divide-gray-200">
                  {metrics.locations.recent.map((location: any, index: number) => (
                    <li key={index} className="py-3">
                      <div className="flex justify-between">
                        <div>
                          <p className="text-sm font-medium text-gray-900">
                            {location.name}
                          </p>
                          <p className="text-sm text-gray-500">
                            {location.brand_name && `${location.brand_name} • `}
                            {location.city && location.state
                              ? `${location.city}, ${location.state}`
                              : 'No location'}
                          </p>
                        </div>
                        <div className="text-sm text-gray-500">
                          {new Date(location.created_at).toLocaleDateString()}
                        </div>
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
