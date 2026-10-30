"""Pin the Loki variable schema used by the provisioned Grafana 11 dashboard."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class GrafanaVariablesTests(unittest.TestCase):
    def test_service_label_values_query(self):
        dashboard = json.loads((ROOT / 'dev/grafana/dashboards/dev-logs.json').read_text())
        service = next(v for v in dashboard['templating']['list'] if v['name'] == 'service')
        self.assertEqual(service['datasource']['uid'], 'agrovesto-loki')
        self.assertEqual(service['query']['type'], 1)  # LokiVariableQueryType.LabelValues
        self.assertEqual(service['query']['label'], 'service')
        self.assertEqual(service['query']['stream'], '{job="docker"}')
        self.assertNotIn('query', service['query'])
        self.assertTrue(service['multi'])
        self.assertTrue(service['includeAll'])
        self.assertEqual(service['allValue'], '.*')
        self.assertEqual(service['refresh'], 2)
        self.assertEqual(service['regex'], '')

    def test_prod_log_panels_use_otlp_loki_labels(self):
        for filename in ('ecs.json', 'services.json'):
            dashboard = json.loads((ROOT / 'monitoring/dashboards' / filename).read_text())
            queries = [
                target.get('expr', '')
                for panel in dashboard['panels']
                for target in panel.get('targets', [])
            ]
            log_queries = [query for query in queries if 'source="app"' in query]
            self.assertTrue(log_queries, f'{filename} should include OTLP application-log panels')
            self.assertTrue(all('service_name=~"$service"' in query for query in log_queries))
            self.assertFalse(any('EcsLogShipperStalled' in query for query in queries))

    def test_ecs_dashboard_has_no_log_shipper_health_panel(self):
        dashboard = json.loads((ROOT / 'monitoring/dashboards/ecs.json').read_text())
        titles = [panel.get('title', '').lower() for panel in dashboard['panels']]
        self.assertFalse(any('log shipper' in title for title in titles))


if __name__ == '__main__':
    unittest.main()
