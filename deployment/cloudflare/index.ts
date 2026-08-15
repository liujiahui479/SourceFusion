

import { Container, getContainer, getRandom } from "@cloudflare/containers";
import type { Env } from "./worker-configuration.d";  

export class PerplexedContainer extends Container {
  defaultPort = 30001; 
  enableInternet = true;
  sleepAfter = "15m";
  envVars = {
    DOMAINS_ALLOW: this.env.DOMAINS_ALLOW,
    GOOGLE_SEARCH_API_KEY: this.env.GOOGLE_SEARCH_API_KEY,
    GOOGLE_SEARCH_ENGINE_ID: this.env.GOOGLE_SEARCH_ENGINE_ID,
    GROQ_API_KEY: this.env.GROQ_API_KEY,
  };
};

const INSTANCE_COUNT = 1;

export default {
  


  async fetch(
    request: Request,
    env: Env
  ): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname.startsWith("/stream") || url.pathname.startsWith("/env")) {
      const containerInstance = await getRandom(env.PERPLEXED_CONTAINER, INSTANCE_COUNT);
      return containerInstance.fetch(request);
    } else { 
      return env.ASSETS.fetch(request);
    }
  },
};
