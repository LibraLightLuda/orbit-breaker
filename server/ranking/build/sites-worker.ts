import handler from "vinext/server/fetch-handler";
import { runWithConnectorBinding } from "../lib/connector-context";
import type { ConnectorBinding } from "../lib/connector-contract.mjs";
import {gameAsset} from "../lib/game-assets.mjs";

export default {
  async fetch(request: Request, env: Cloudflare.Env, ctx: ExecutionContext<{ CONNECTORS?: ConnectorBinding }>) {
    const path=new URL(request.url).pathname;
    if(path==='/game')return Response.redirect(new URL('/game/',request.url),308);
    if(path.startsWith('/game/'))return gameAsset(request,env);
    if ((env as unknown as {RUNTIME_PROBE?:string}).RUNTIME_PROBE === '1' && new URL(request.url).pathname === '/__sites_probe/ws') {
      if (request.headers.get('Upgrade') !== 'websocket') return new Response('WebSocket required',{status:426});
      const pair=new WebSocketPair();
      pair[1].accept();
      pair[1].addEventListener('message',event=>pair[1].send(event.data));
      return new Response(null,{status:101,webSocket:pair[0]});
    }
    let binding = ctx.props?.CONNECTORS;
    // Local preview emulates the same request-scoped capability. This branch and
    // the auxiliary service binding are absent from production builds.
    if (import.meta.env.DEV && !binding && env.CONNECTORS) {
      const preview = env.CONNECTORS;
      const expiresAt = Date.now() + 60_000;
      binding = {
        async getContext() {
          if (Date.now() >= expiresAt) return { status: "request_context_expired" };
          return preview.getContext?.() ?? { status: "binding_unavailable" };
        },
        async invoke(connectorId, actionName, args) {
          if (Date.now() >= expiresAt) {
            return { status: "request_context_expired", message: "This request has expired. Please try again." };
          }
          return preview.invoke(connectorId, actionName, args);
        },
      };
    }
    return runWithConnectorBinding(binding, () => handler.fetch(request, env, ctx));
  },
};
