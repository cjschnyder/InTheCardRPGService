import { util } from '@aws-appsync/utils';

export function request(ctx) {
  return {
    operation: 'Query',
    index: 'UserCharactersIndex',
    query: {
      expression: 'userId = :userId',
      expressionValues: util.dynamodb.toMapValues({
        ':userId': ctx.identity.sub
      })
    }
  };
}

export function response(ctx) {
  if (ctx.error) {
    util.error(ctx.error.message, ctx.error.type);
  }
  return ctx.result.items;
}