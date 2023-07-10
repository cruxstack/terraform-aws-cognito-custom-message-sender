import { PublishCommand, PublishCommandInput, PublishCommandOutput, SNSClient } from '@aws-sdk/client-sns';
import { AppError, AppErrorName } from '../commons/errors';
import { logger } from '../commons/logger';
import { IMessageClient, SmsMessagePayload } from '../commons/types';

export class AwsSms implements IMessageClient<SmsMessagePayload> {
  constructor(private readonly _client: SNSClient) { }

  public readonly send = async (payload: SmsMessagePayload): Promise<void> => {
    const input: PublishCommandInput = {
      PhoneNumber: payload.destination,
      Message: payload.message,
      MessageAttributes: {
        'AWS.SNS.SMS.SMSType': {
          DataType: 'String',
          StringValue: payload.messageType,
        },
      },
    };

    if (payload.shortCode) {
      input.MessageAttributes = {
        ...input.MessageAttributes,
        'AWS.MM.SMS.OriginationNumber': {
          DataType: 'String',
          StringValue: payload.shortCode,
        },
      };
    }

    if (payload.senderId) {
      input.MessageAttributes = {
        ...input.MessageAttributes,
        'AWS.SNS.SMS.SenderID': {
          DataType: 'String',
          StringValue: payload.senderId,
        },
      };
    }

    const response = await this._publish(input);

    logger.debug({
      input: {
        messageId: response.MessageId,
        phoneNumber: input.PhoneNumber,
        message: 'REDACTED',
        senderId: input.MessageAttributes?.['AWS.SNS.SMS.SenderID']?.StringValue,
        shortCode: input.MessageAttributes?.['AWS.SNS.SMS.OriginationNumber']?.StringValue,
      },
    }, 'sms sent');
  };

  private readonly _publish = async (input: PublishCommandInput): Promise<PublishCommandOutput> => {
    const command: PublishCommand = new PublishCommand(input);
    return this._client.send(command);
  };
}
