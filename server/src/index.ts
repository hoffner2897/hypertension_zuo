import { loadConfig } from "./config.js";
import { createApp } from "./app.js";

const config = loadConfig();
const app = createApp(config);

app.listen(config.port, () => {
  console.log(`BPHealth server running on http://localhost:${config.port}`);
  console.log(`Recognition mode: ${config.recognitionMode}`);
});
