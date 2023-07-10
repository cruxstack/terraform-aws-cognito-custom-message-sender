import { PutItemCommandOutput, QueryCommandOutput, PutItemCommandInput, QueryCommandInput, DynamoDBClient, PutItemCommand, QueryCommand } from '@aws-sdk/client-dynamodb';
import { mockClient } from 'aws-sdk-client-mock';
import 'aws-sdk-client-mock-jest';
import { AwsDdb } from './aws-ddb';

describe('AwsDdb Service', () => {
  let mockDdbPutResponse: PutItemCommandOutput;
  let mockDdbQueryResponse: QueryCommandOutput;

  let mockDdbPutInput: PutItemCommandInput;
  let mockDdbQueryInput: QueryCommandInput;

  beforeEach(() => {
    mockDdbPutResponse = {
      '$metadata': {},
      Attributes: {},
    };

    mockDdbQueryResponse = {
      '$metadata': {},
      Items: [],
    };

    mockDdbPutInput = {
      TableName: 'test-table',
      Item: {
        test: {
          S: 'test',
        },
      },
    };

    mockDdbQueryInput = {
      TableName: 'test-table',
      KeyConditionExpression: 'test = :test',
      ExpressionAttributeValues: {
        ':test': {
          S: 'test',
        },
      },
    };
  });

  it('should put item via ddb put command', async () => {
    const mockDdb = mockClient(DynamoDBClient);
    mockDdb.on(PutItemCommand).resolves(mockDdbPutResponse);

    const client = new AwsDdb(mockDdb as any);
    await client.putItem(mockDdbPutInput);

    expect(mockDdb).toHaveReceivedCommandTimes(PutItemCommand, 1);
    expect(mockDdb).toHaveReceivedCommandWith(PutItemCommand, mockDdbPutInput);
  });

  it('should query item via ddb query command', async () => {
    const mockDdb = mockClient(DynamoDBClient);
    mockDdb.on(QueryCommand).resolves(mockDdbQueryResponse);

    const client = new AwsDdb(mockDdb as any);
    await client.query(mockDdbQueryInput);

    expect(mockDdb).toHaveReceivedCommandTimes(QueryCommand, 1);
    expect(mockDdb).toHaveReceivedCommandWith(QueryCommand, mockDdbQueryInput);
  });
});
