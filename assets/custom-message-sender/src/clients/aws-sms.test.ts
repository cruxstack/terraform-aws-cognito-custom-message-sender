import { SNSClient, PublishCommand, PublishCommandInput, PublishCommandOutput } from '@aws-sdk/client-sns';
import { mockClient } from 'aws-sdk-client-mock';
import { AwsSms } from './aws-sms';
import 'aws-sdk-client-mock-jest';
import { SmsMessagePayload } from '../commons/types';
import { AppError, AppErrorName } from '../commons/errors';

describe('AwsSms Service', () => {
  let mockSnsPublishResponse: PublishCommandOutput;

  let mockSmsMessagePayload: SmsMessagePayload;

  let mockSmsMessageSnsPublishCommandInput: PublishCommandInput;

  beforeEach(() => {
    mockSnsPublishResponse = {
      '$metadata': {},
      MessageId: '00000000-0000-0000-0000-000000000000',
    };

    mockSmsMessagePayload = {
      destination: '+18135555555',
      message: 'You verification code: 1234',
      messageType: 'Transactional',
    };

    mockSmsMessageSnsPublishCommandInput = {
      PhoneNumber: mockSmsMessagePayload.destination,
      Message: mockSmsMessagePayload.message,
      MessageAttributes: {
        'AWS.SNS.SMS.SMSType': {
          DataType: 'String',
          StringValue: mockSmsMessagePayload.messageType,
        },
      },
    };
  });

  it('should send sns via sns publish command', async () => {
    const mockSns = mockClient(SNSClient);
    mockSns.on(PublishCommand).resolves(mockSnsPublishResponse);

    const client = new AwsSms(mockSns as any);
    await client.send(mockSmsMessagePayload);

    expect(mockSns).toHaveReceivedCommandTimes(PublishCommand, 1);
    expect(mockSns).toHaveReceivedCommandWith(PublishCommand, mockSmsMessageSnsPublishCommandInput);
  });

  it('should send sns with sender id via sns publish command', async () => {
    mockSmsMessagePayload.senderId = 'EXAMPLE';
    mockSmsMessageSnsPublishCommandInput.MessageAttributes = {
      ...mockSmsMessageSnsPublishCommandInput.MessageAttributes,
      'AWS.SNS.SMS.SenderID': {
        DataType: 'String',
        StringValue: mockSmsMessagePayload.senderId,
      },
    };
    const mockSns = mockClient(SNSClient);
    mockSns.on(PublishCommand).resolves(mockSnsPublishResponse);

    const client = new AwsSms(mockSns as any);
    await client.send(mockSmsMessagePayload);

    expect(mockSns).toHaveReceivedCommandTimes(PublishCommand, 1);
    expect(mockSns).toHaveReceivedCommandWith(PublishCommand, mockSmsMessageSnsPublishCommandInput);
  });

  it('should send sns with short code via sns publish command', async () => {
    mockSmsMessagePayload.shortCode = '12345';
    mockSmsMessageSnsPublishCommandInput.MessageAttributes = {
      ...mockSmsMessageSnsPublishCommandInput.MessageAttributes,
      'AWS.MM.SMS.OriginationNumber': {
        DataType: 'String',
        StringValue: mockSmsMessagePayload.shortCode,
      },
    };
    const mockSns = mockClient(SNSClient);
    mockSns.on(PublishCommand).resolves(mockSnsPublishResponse);

    const client = new AwsSms(mockSns as any);
    await client.send(mockSmsMessagePayload);

    expect(mockSns).toHaveReceivedCommandTimes(PublishCommand, 1);
    expect(mockSns).toHaveReceivedCommandWith(PublishCommand, mockSmsMessageSnsPublishCommandInput);
  });

  afterEach(() => {
    jest.resetAllMocks();
  });
});
