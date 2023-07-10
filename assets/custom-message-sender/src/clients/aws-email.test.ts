
import { GetTemplateCommand, SendEmailCommand, SendEmailCommandInput, SendEmailCommandOutput, SESClient } from '@aws-sdk/client-ses';
import { mockClient } from 'aws-sdk-client-mock';
import 'aws-sdk-client-mock-jest';
import { EmailMessagePayload } from '../commons/types';
import { AwsEmail } from './aws-email';

describe('AwsEmail Service', () => {
  let awsEmail: AwsEmail;
  let mockEmailMessagePayload: EmailMessagePayload;
  let mockEmailMessageSnsSendCommandInput: SendEmailCommandInput;
  let mockEmailMessageSnsSendCommandOutput: SendEmailCommandOutput;

  beforeAll(() => {
    mockEmailMessagePayload = {
      source: 'EXAMPLE <no-reply@test.example.com>',
      destination: 'test_email_address',
      message: 'test email message',
      subject: 'test_subject',
    };
    mockEmailMessageSnsSendCommandInput = {
      Source: mockEmailMessagePayload.source,
      Destination: {
        ToAddresses: [mockEmailMessagePayload.destination],
      },
      Message: {
        Subject: {
          Data: mockEmailMessagePayload.subject,
        },
        Body: {
          Html: {
            Data: mockEmailMessagePayload.message,
          },
        },
      },
    };
    mockEmailMessageSnsSendCommandOutput = {
      $metadata: { httpStatusCode: 200 },
      MessageId: 'test_message_id',
    };

  });

  afterEach(() => {
    jest.resetAllMocks();
  });


  it('should throw the error when an error occurs', async () => {
    const mockSESClient = mockClient(SESClient);
    awsEmail = new AwsEmail(mockSESClient as any);
    mockSESClient.on(SendEmailCommand).resolves({
      ...mockEmailMessageSnsSendCommandOutput, $metadata: {
        httpStatusCode: 500,
      },
    });
    try {
      await awsEmail.send(mockEmailMessagePayload);
    } catch (error) {
      expect(error).toBeDefined();
    }
    expect(mockSESClient).toHaveReceivedCommandTimes(SendEmailCommand, 1);
    expect(mockSESClient).toHaveReceivedCommandWith(SendEmailCommand, mockEmailMessageSnsSendCommandInput);
  });

  it('should send an email via SendEmailCommand', async () => {
    const mockSESClient = mockClient(SESClient);
    awsEmail = new AwsEmail(mockSESClient as any);
    mockSESClient.on(SendEmailCommand).resolves(mockEmailMessageSnsSendCommandOutput);

    try {
      await awsEmail.send(mockEmailMessagePayload);
    } catch (error) {
      expect(error).not.toBeDefined();
    }
    expect(mockSESClient).toHaveReceivedCommandTimes(SendEmailCommand, 1);
    expect(mockSESClient).toHaveReceivedCommandWith(SendEmailCommand, mockEmailMessageSnsSendCommandInput);
  });

  it('should get template by name', async () => {
    const mockSESClient = mockClient(SESClient);
    let result;
    awsEmail = new AwsEmail(mockSESClient as any);
    mockSESClient.on(GetTemplateCommand).resolves({
      Template: {
        TemplateName: 'tmpl1',
        HtmlPart: 'tmplhtml1',
      },
    });
    try {
      result = await awsEmail.getTemplate('tmpl1');
    } catch (error) {
      expect(error).not.toBeDefined();
    }
    expect(result).toEqual('tmplhtml1');
  });

  it('should return an empty value if no templates are found', async () => {
    const mockSESClient = mockClient(SESClient);
    let result;
    awsEmail = new AwsEmail(mockSESClient as any);
    mockSESClient.on(GetTemplateCommand).resolves({
      Template: {
        TemplateName: 'tmpl1',
      },
    });
    try {
      result = await awsEmail.getTemplate('tmpl1');
    } catch (error) {
      expect(error).not.toBeDefined();
    }
    expect(result).toEqual('');
  });
});
