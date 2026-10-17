import {env} from 'cloudflare:workers';
import {records} from '../../lib/records.mjs';
export const dynamic='force-dynamic';
export const GET=(request:Request)=>records(env).GET(request);
export const POST=(request:Request)=>records(env).POST(request);
export const OPTIONS=(request:Request)=>records(env).OPTIONS(request);
