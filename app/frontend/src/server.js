import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = 3000;

app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${req.method} ${req.url} - ${req.ip}`);
  next();
});

app.use(express.static(path.join(__dirname, '../public')));

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Frontend running at http://0.0.0.0:${PORT}`);
});
