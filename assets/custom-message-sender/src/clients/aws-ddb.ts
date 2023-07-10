import { DynamoDBClient, PutItemCommand, PutItemCommandInput, PutItemCommandOutput, QueryCommand, QueryCommandInput, QueryCommandOutput } from '@aws-sdk/client-dynamodb';
import { IDocumentClient } from '../commons/types';

export interface PutItemInput extends PutItemCommandInput { }
export interface PutItemOutput extends PutItemCommandOutput { }
export interface QueryInput extends QueryCommandInput { }
export interface QueryOutput extends QueryCommandOutput { }

export interface AwsDdbClient extends IDocumentClient<PutItemInput, PutItemOutput, QueryInput, QueryOutput> { }

export class AwsDdb implements AwsDdbClient {
  constructor(private readonly _client: DynamoDBClient) { }

  public readonly putItem = async (input: PutItemInput): Promise<PutItemOutput> => {
    const command = new PutItemCommand(input);
    const response = await this._client.send(command);
    return response;
  };

  public readonly query = async (input: QueryInput): Promise<QueryOutput> => {
    const command = new QueryCommand(input);
    const response = this._client.send(command);
    return response;
  };
}
