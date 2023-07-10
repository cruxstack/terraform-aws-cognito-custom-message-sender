import { AwsDdbClient, PutItemInput, QueryInput, QueryOutput } from '../clients/aws-ddb';
import { logger } from '../commons/logger';
import { SmsSenderTrigger, SmsSenderTriggerType } from '../services/sms-sender';

const MIN_IN_MILLIS = 60 * 1000;

export interface HistoryModel {
  type: 'sms' | 'email';
  trigger: SmsSenderTrigger | SmsSenderTriggerType;
  userId: string;
  userEmailAddress: string;
  userPhoneNumber: string;
  userPhoneNumberCountry: string;
  sentAt?: string;
  sentAtEpoch?: number;
}

export interface IHistoryRepository {
  save: (model: HistoryModel) => Promise<void>;
  getCountByUserId(id: string, since: number): Promise<number>;
  getCountByPhoneNumber(phoneNumber: string, since: number): Promise<number>;
}

export interface IHistoryRepositoryTableConfig {
  name: string;
  ttlLength: number;
}

export interface IHistoryRepositoryConfig {
  historyTable: IHistoryRepositoryTableConfig
}

export class HistoryRepository {
  private readonly _client: AwsDdbClient;

  private readonly _tableName: string;

  private readonly _ttlLength: number;

  constructor(config: IHistoryRepositoryConfig, client: AwsDdbClient) {
    this._client = client;
    this._tableName = config.historyTable.name;
    this._ttlLength = config.historyTable.ttlLength * MIN_IN_MILLIS;
  }

  readonly save = async (model: HistoryModel): Promise<void> => {
    const sentDateTime = new Date();
    const input: PutItemInput = {
      TableName: this._tableName,
      Item: {
        historyId: { S: `${model.type}-${model.userId}-${sentDateTime.getTime()}` },
        type: { S: model.type },
        trigger: { S: model.trigger },
        userId: { S: model.userId },
        userEmailAddress: { S: model.userEmailAddress },
        userPhoneNumber: { S: model.userPhoneNumber },
        userPhoneNumberCountry: { S: model.userPhoneNumberCountry },
        sentAt: { S: sentDateTime.toISOString() },
        sentAtEpoch: { N: sentDateTime.getTime().toString() },
        ttl: { N: (sentDateTime.getTime() + this._ttlLength).toString() },
      },
    };

    try {
      await this._client.putItem(input);
      logger.debug({ model: { ...model, sendAt: sentDateTime.toISOString() } }, 'saved history');
    } catch (err: unknown) {
      logger.error({ err }, 'failed to save history');
    }
  };

  readonly getCountByUserId = async (id: string, sinceTime?: number): Promise<number> => {
    const result = await this._getByUserId(id, sinceTime, true);
    const count = result?.Count ?? 0;
    logger.debug({ id, sinceTime, count }, 'request to get count by user id completed');
    return count;
  };

  readonly getCountByPhoneNumber = async (phoneNumber: string, sinceTime?: number): Promise<number> => {
    const result = await this._getByPhoneNumber(phoneNumber, sinceTime, true);
    const count = result?.Count ?? 0;
    logger.debug({ phoneNumber, sinceTime, count }, 'request to get count by phone number completed');
    return count;
  };

  private readonly _getByUserId = async (id: string, sinceTime?: number, countOnly?: boolean): Promise<QueryOutput | undefined> => {
    const query: QueryInput = {
      TableName: this._tableName,
      IndexName: 'userSid-index',
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: {
        ':userId': { S: id },
      },
      Select: !!countOnly ? 'COUNT' : 'ALL_ATTRIBUTES',
    };
    if (sinceTime) {
      query.KeyConditionExpression = `${query.KeyConditionExpression} AND sentAtEpoch >= :sentAtEpoch`;
      query.ExpressionAttributeValues = query.ExpressionAttributeValues || {}; // prevents ts error
      query.ExpressionAttributeValues[':sentAtEpoch'] = { N: sinceTime.toString() };
    }
    try {
      return await this._client.query(query);
    } catch (err: unknown) {
      logger.error({ err }, 'failed to get history by user id');
      return undefined;
    }
  };

  private readonly _getByPhoneNumber = async (phoneNumber: string, sinceTime?: number, countOnly?: boolean): Promise<QueryOutput | undefined> => {
    const query: QueryInput = {
      TableName: this._tableName,
      IndexName: 'userPhoneNumber-index',
      KeyConditionExpression: 'userPhoneNumber = :userPhoneNumber',
      ExpressionAttributeValues: {
        ':userPhoneNumber': { S: phoneNumber },
      },
      Select: !!countOnly ? 'COUNT' : 'ALL_ATTRIBUTES',
    };
    if (sinceTime) {
      query.KeyConditionExpression = `${query.KeyConditionExpression} AND sentAtEpoch >= :sentAtEpoch`;
      query.ExpressionAttributeValues = query.ExpressionAttributeValues || {}; // prevents ts error
      query.ExpressionAttributeValues[':sentAtEpoch'] = { N: sinceTime.toString() };
    }
    try {
      return await this._client.query(query);
    } catch (err: unknown) {
      logger.error({ err }, 'failed to get history by user phone number');
      return undefined;
    }
  };

}
