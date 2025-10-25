import { util } from '@aws-appsync/utils';
import * as ddb from '@aws-appsync/utils/dynamodb';

export function request(ctx) {
  const now = util.time.nowISO8601();
  
  const item = {
    userId: ctx.identity.sub,
    email: ctx.args.email,
    username: ctx.args.username,
    createdAt: now,
    lastLogin: now
  };

  return ddb.put({ key: { userId: ctx.identity.sub }, item });
}

export function response(ctx) {
  if (ctx.error) {
    util.error(ctx.error.message, ctx.error.type);
  }
  return ctx.result;
}