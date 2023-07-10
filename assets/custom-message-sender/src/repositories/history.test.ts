import { SmsSenderTrigger } from '../services/sms-sender';
import { HistoryModel, HistoryRepository, IHistoryRepositoryConfig } from './history';
import { AwsDdbClient, PutItemOutput, QueryOutput } from '../clients/aws-ddb';

describe('HistoryRepository Class', () => {
  let mClient: AwsDdbClient;

  let mConfig: IHistoryRepositoryConfig;

  let mHistoryModel: HistoryModel;

  beforeEach(() => {
    mClient = {
      putItem: jest.fn().mockResolvedValue({
        $metadata: {},
        Attributes: {},
        ConsumedCapacity: {},
        ItemCollectionMetrics: {},
      } as PutItemOutput),
      query: jest.fn().mockResolvedValue({
        $metadata: {},
        ConsumedCapacity: {},
        Count: 0,
        Items: [],
      } as QueryOutput),
    };

    mConfig = {
      historyTable: {
        name: 'test-table',
        ttlLength: 1,
      },
    };

    mHistoryModel = {
      type: 'sms',
      trigger: SmsSenderTrigger.SIGN_UP,
      userId: 'abc123',
      userEmailAddress: 'foobar@email.com',
      userPhoneNumber: '+155555555',
      userPhoneNumberCountry: 'US',
    };
  });

  it('should save history', async () => {
    const repository = new HistoryRepository(mConfig, mClient);
    let error: unknown;

    try {
      await repository.save(mHistoryModel);
    } catch (err: unknown) {
      error = err;
    }

    expect(error).toBeUndefined();
    expect(mClient.putItem).toHaveBeenCalledTimes(1);
  });

  it('should return count of record selecting via user id', async () => {
    const repository = new HistoryRepository(mConfig, mClient);
    let count: number = -1;
    let error: unknown;

    try {
      count = await repository.getCountByUserId(mHistoryModel.userId);
    } catch (err: unknown) {
      error = err;
    }

    expect(error).toBeUndefined();
    expect(mClient.query).toHaveBeenCalledTimes(1);
    expect(count).toEqual(0);
  });

  it('should return count of record selecting via user phone number', async () => {
    const repository = new HistoryRepository(mConfig, mClient);
    let count: number = -1;
    let error: unknown;

    try {
      count = await repository.getCountByPhoneNumber(mHistoryModel.userPhoneNumber);
    } catch (err: unknown) {
      error = err;
    }

    expect(error).toBeUndefined();
    expect(mClient.query).toHaveBeenCalledTimes(1);
    expect(count).toEqual(0);
  });

  it('should filter for phone number entries sent since a specific date', async () => {
    const repository = new HistoryRepository(mConfig, mClient);
    let count: number = -1;
    let error: unknown;

    try {
      count = await repository.getCountByPhoneNumber(mHistoryModel.userPhoneNumber, 100000);
    } catch (err: unknown) {
      error = err;
    }

    expect(error).toBeUndefined();
    expect(count).toEqual(0);
    expect(mClient.query).toHaveBeenCalledTimes(1);
    expect(mClient.query).toHaveBeenCalledWith({
      TableName: 'test-table',
      IndexName: 'userPhoneNumber-index',
      ExpressionAttributeValues: {
        ':sentAtEpoch': { 'N': '100000' },
        ':userPhoneNumber': { 'S': '+155555555' },
      },
      KeyConditionExpression: 'userPhoneNumber = :userPhoneNumber AND sentAtEpoch >= :sentAtEpoch',
      Select: 'COUNT',
    });
  });

  it('should filter for user id entries sent since a specific date', async () => {
    const repository = new HistoryRepository(mConfig, mClient);
    let count: number = -1;
    let error: unknown;

    try {
      count = await repository.getCountByUserId(mHistoryModel.userId, 100000);
    } catch (err: unknown) {
      error = err;
    }

    expect(error).toBeUndefined();
    expect(count).toEqual(0);
    expect(mClient.query).toHaveBeenCalledTimes(1);
    expect(mClient.query).toHaveBeenCalledWith({
      TableName: 'test-table',
      IndexName: 'userSid-index',
      ExpressionAttributeValues: {
        ':sentAtEpoch': { 'N': '100000' },
        ':userId': { 'S': 'abc123' },
      },
      KeyConditionExpression: 'userId = :userId AND sentAtEpoch >= :sentAtEpoch',
      Select: 'COUNT',
    });
  });

  it('should return 0 if error access ddb', async () => {
    mClient = Object.assign(mClient, {
      query: jest.fn().mockRejectedValue(new Error('mock error')),
    });
    const repository = new HistoryRepository(mConfig, mClient);
    let userScopeByPhoneNumber: number = -1;
    let userScopeByUserId: number = -1;
    let error: unknown;

    try {
      userScopeByPhoneNumber = await repository.getCountByPhoneNumber(mHistoryModel.userPhoneNumber);
      userScopeByUserId = await repository.getCountByUserId(mHistoryModel.userId);
    } catch (err: unknown) {
      error = err;
    }

    expect(error).toBeUndefined();
    expect(mClient.query).toHaveBeenCalledTimes(2);
    expect(userScopeByPhoneNumber).toEqual(0);
    expect(userScopeByUserId).toEqual(0);
  });

  it('should not throw error if ddb client throws error when saving', async () => {
    mClient = Object.assign(mClient, {
      put: jest.fn().mockRejectedValue(new Error('mock error')),
    });
    const repository = new HistoryRepository(mConfig, mClient);
    let error: unknown;

    try {
      await repository.save(mHistoryModel);
    } catch (err: unknown) {
      error = err;
    }

    expect(error).toBeUndefined();
    expect(mClient.putItem).toHaveBeenCalledTimes(1);
  });


  it('should return all attributes if countOnly flag is false for getByUserId', async () => {
    const repository = new HistoryRepository(mConfig, mClient);
    let result: QueryOutput | undefined;
    let error: unknown;

    try {
      result = await (repository as any)._getByUserId(mHistoryModel.userId, undefined, false);
    } catch (err: unknown) {
      error = err;
    }

    expect(error).toBeUndefined();
    expect(mClient.query).toHaveBeenCalledTimes(1);
    expect(mClient.query).toHaveBeenCalledWith(expect.objectContaining({ Select: 'ALL_ATTRIBUTES' }));
    expect(result).toEqual(expect.anything());
  });

  it('should return all attributes if countOnly flag is false for getByPhoneNumber', async () => {
    const repository = new HistoryRepository(mConfig, mClient);
    let result: QueryOutput | undefined;
    let error: unknown;

    try {
      result = await (repository as any)._getByPhoneNumber(mHistoryModel.userPhoneNumber, undefined, false);
    } catch (err: unknown) {
      error = err;
    }

    expect(error).toBeUndefined();
    expect(mClient.query).toHaveBeenCalledTimes(1);
    expect(mClient.query).toHaveBeenCalledWith(expect.objectContaining({ Select: 'ALL_ATTRIBUTES' }));
    expect(result).toEqual(expect.anything());
  });

});
