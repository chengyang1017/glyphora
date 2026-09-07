import OpenAI from 'openai';
import { zodTextFormat } from 'openai/helpers/zod';
import { z } from 'zod';

export type ProfileTagTranslationInput = {
  tags: string[];
  targetLanguageCode: string;
  targetLanguageName: string;
  profileContext: string;
};

const profileTagTranslationOutputSchema = z.object({
  translations: z.array(
    z.object({
      original: z.string(),
      translated: z.string(),
    }),
  ),
});

let openaiClient: OpenAI | null = null;

function getOpenAiClient(): OpenAI {
  const apiKey = process.env.OPENAI_API_KEY?.trim();

  if (!apiKey) {
    throw new Error('OPENAI_API_KEY is not configured');
  }

  openaiClient ??= new OpenAI({
    apiKey,
    timeout: 60_000,
  });

  return openaiClient;
}

export async function translateProfileTagsWithAi(
  input: ProfileTagTranslationInput,
): Promise<{
  translations: Array<{
    original: string;
    translated: string;
  }>;
}> {
  if (input.tags.length === 0) {
    return { translations: [] };
  }

  const openai = getOpenAiClient();

  const response = await openai.responses.parse({
    model: 'gpt-5-mini',
    store: false,
    instructions: [
      'You translate short user profile tags for a multilingual social platform.',
      '',
      'Translate every tag into the requested target language.',
      'Return exactly one output item for every input tag and preserve input order.',
      '',
      'Requirements:',
      '- Keep the original field exactly equal to the supplied tag.',
      '- Use the supplied profileContext only to disambiguate short or ambiguous tags.',
      '- Preserve technology names, programming language names, brands, usernames, proper nouns, and terms that are normally left untranslated.',
      '- If a tag is already natural in the target language, keep it unchanged.',
      '- If a reliable natural translation does not exist, keep the original unchanged.',
      '- Do not explain the translation.',
      '- Do not add hashtags.',
      '- Keep each translated tag short enough to work as a profile chip.',
    ].join('\n'),
    input: JSON.stringify(input),
    text: {
      format: zodTextFormat(
        profileTagTranslationOutputSchema,
        'profile_tag_translation',
      ),
    },
  });

  const translated = response.output_parsed;

  if (translated == null) {
    throw new Error('OpenAI returned no parsed profile tag translation');
  }

  if (translated.translations.length !== input.tags.length) {
    throw new Error('OpenAI returned an unexpected number of profile tag translations');
  }

  return translated;
}
