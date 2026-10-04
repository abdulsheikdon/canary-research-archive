import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  thresholds: {
    http_req_failed: ['rate<0.1'], 
  },
};

export default function () {
  const res = http.get(`http://${__ENV.TARGET}`);
  check(res, { 'status is 200': (r) => r.status === 200 });
  sleep(1);
}