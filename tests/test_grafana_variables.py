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


if __name__ == '__main__':
    unittest.main()
