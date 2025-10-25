import { util } from '@aws-appsync/utils';
import * as ddb from '@aws-appsync/utils/dynamodb';

export function request(ctx) {
  const { characterId, ...values } = ctx.args;
  values.updatedAt = util.time.nowISO8601();

  return ddb.update({
    key: { characterId, userId: ctx.identity.sub },
    update: values
  });
}

export function response(ctx) {
  if (ctx.error) {
    util.error(ctx.error.message, ctx.error.type);
  }
  return ctx.result;
}