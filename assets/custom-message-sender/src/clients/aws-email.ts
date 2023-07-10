import { SendEmailCommand, SendEmailCommandInput, SESClient, SendEmailCommandOutput, GetTemplateCommand, GetTemplateCommandInput, GetTemplateCommandOutput } from '@aws-sdk/client-ses';
import { logger } from '../commons/logger';
import { EmailMessagePayload, IMessageClient } from '../commons/types';

export class AwsEmail implements IMessageClient<EmailMessagePayload> {
  constructor(private readonly _client: SESClient) { }

  public readonly send = async (payload: EmailMessagePayload): Promise<void> => {
    const input: SendEmailCommandInput = {
      Source: payload.source,
      Destination: {
        ToAddresses: [payload.destination],
      },
      Message: {
        Subject: {
          Data: payload.subject,
        },
        Body: {
          Html: {
            Data: payload.message,
          },
        },
      },
    };

    const response = await this._publish(input);
    logger.debug({ messageId: response.MessageId }, 'email sent');
  };

  public readonly getTemplate = async (name: string): Promise<string> => {
    const result = await this._getTemplate({ TemplateName: name });
    return result.Template?.HtmlPart || result.Template?.TextPart || '';
  };

  private readonly _getTemplate = async (input: GetTemplateCommandInput): Promise<GetTemplateCommandOutput> => {
    const command = new GetTemplateCommand(input);
    return this._client.send(command);
  };

  private readonly _publish = async (input: SendEmailCommandInput): Promise<SendEmailCommandOutput> => {
    const command = new SendEmailCommand(input);
    return this._client.send(command);
  };
}
