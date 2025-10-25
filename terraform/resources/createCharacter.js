import { util } from '@aws-appsync/utils';
import * as ddb from '@aws-appsync/utils/dynamodb';

export function request(ctx) {
  const characterId = util.autoId();
  const now = util.time.nowISO8601();
  
  const item = {
    characterId,
    userId: ctx.identity.sub,
    name: ctx.args.name,
    species: ctx.args.species,
    starterClass: ctx.args.starterClass,
    priestOption: ctx.args.priestOption,
    gear: ctx.args.gear,
    hand: ctx.args.hand,
    discard: ctx.args.discard,
    discardRest: ctx.args.discardRest,
    customCards: ctx.args.customCards,
    createdAt: now,
    updatedAt: now
  };

  return ddb.put({ key: { characterId, userId: ctx.identity.sub }, item });
}

export function response(ctx) {
  if (ctx.error) {
    util.error(ctx.error.message, ctx.error.type);
  }
  return ctx.result;
}