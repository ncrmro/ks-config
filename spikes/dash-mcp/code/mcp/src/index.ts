#!/usr/bin/env bun
import { z } from "zod";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { tools, type ToolName } from "./tools.js";

const server = new Server(
  { name: "dash-mcp", version: "0.0.0" },
  { capabilities: { tools: {} } },
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: Object.entries(tools).map(([name, def]) => ({
    name,
    description: def.description,
    inputSchema: z.toJSONSchema(def.input) as Record<string, unknown>,
  })),
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const name = req.params.name as ToolName;
  const tool = tools[name];
  if (!tool) {
    return {
      isError: true,
      content: [{ type: "text", text: `unknown tool: ${name}` }],
    };
  }
  const parsed = tool.input.safeParse(req.params.arguments ?? {});
  if (!parsed.success) {
    return {
      isError: true,
      content: [
        {
          type: "text",
          text: `invalid arguments: ${JSON.stringify(parsed.error.issues)}`,
        },
      ],
    };
  }
  try {
    const result = await (tool.run as (args: unknown) => Promise<unknown>)(
      parsed.data,
    );
    return {
      content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
    };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return { isError: true, content: [{ type: "text", text: msg }] };
  }
});

await server.connect(new StdioServerTransport());
console.error("[dash-mcp/mcp] stdio server ready");
