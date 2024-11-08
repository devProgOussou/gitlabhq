import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { IndexMlModels } from '~/ml/model_registry/apps';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import EmptyState from '~/ml/model_registry/components/model_list_empty_state.vue';
import ActionsDropdown from '~/ml/model_registry/components/actions_dropdown.vue';
import SearchableTable from '~/ml/model_registry/components/searchable_table.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import getModelsQuery from '~/ml/model_registry/graphql/queries/get_models.query.graphql';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import waitForPromises from 'helpers/wait_for_promises';
import { describeSkipVue3, SkipReason } from 'helpers/vue3_conditional';
import { modelsQuery, modelWithOneVersion, modelWithoutVersion } from '../graphql_mock_data';

Vue.use(VueApollo);

const defaultProps = {
  projectPath: 'path/to/project',
  canWriteModelRegistry: false,
  maxAllowedFileSize: 99999,
  markdownPreviewPath: '/markdown-preview',
  createModelPath: 'path/to/project/-/ml/models/new,',
};

const skipReason = new SkipReason({
  name: 'ml/model_registry/apps/index_ml_models',
  reason: 'OOM on the worker',
  issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/458412',
});

describeSkipVue3(skipReason, () => {
  let wrapper;
  let apolloProvider;

  const createWrapper = async ({
    props = {},
    resolver = jest.fn().mockResolvedValue(modelsQuery()),
  } = {}) => {
    const requestHandlers = [[getModelsQuery, resolver]];
    apolloProvider = createMockApollo(requestHandlers);

    const propsData = {
      ...defaultProps,
      ...props,
    };

    wrapper = mountExtended(IndexMlModels, {
      apolloProvider,
      propsData,
    });

    await waitForPromises();
  };

  beforeEach(() => {
    jest.spyOn(Sentry, 'captureException').mockImplementation();
  });

  const emptyQueryResolver = () => jest.fn().mockResolvedValue(modelsQuery([]));

  const findSearchableTable = () => wrapper.findComponent(SearchableTable);
  const findEmptyState = () => wrapper.findComponent(EmptyState);
  const findTitleArea = () => wrapper.findComponent(TitleArea);
  const findModelCountMetadataItem = () => wrapper.findByTestId('metadata-item');
  const findModelCreate = () => wrapper.findByTestId('create-model-button');
  const findActionsDropdown = () => wrapper.findComponent(ActionsDropdown);

  describe('header', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('displays the title', () => {
      expect(findTitleArea().text()).toContain('Model registry');
    });

    it('renders the extra actions button', () => {
      expect(findActionsDropdown().exists()).toBe(true);
    });
  });

  describe('empty state', () => {
    it('shows empty state', async () => {
      await createWrapper({ resolver: emptyQueryResolver() });

      expect(findEmptyState().props()).toMatchObject({
        title: 'Import your machine learning models',
        description:
          'Create your machine learning using GitLab directly or using the MLflow client',
        primaryText: 'Create model',
      });
    });
  });

  describe('create button', () => {
    describe('when user has no permission to write model registry', () => {
      it('does not display create button', async () => {
        await createWrapper({ resolver: emptyQueryResolver() });

        expect(findModelCreate().exists()).toBe(false);
      });
    });

    describe('when user has permission to write model registry', () => {
      it('displays create button', async () => {
        await createWrapper({
          props: { canWriteModelRegistry: true },
          resolver: emptyQueryResolver(),
        });

        expect(findModelCreate().exists()).toBe(true);
      });
    });
  });

  describe('when loading data fails', () => {
    beforeEach(async () => {
      const error = new Error('Failure!');

      await createWrapper({ resolver: jest.fn().mockRejectedValue(error) });
    });

    it('error message is displayed', () => {
      expect(findSearchableTable().props('errorMessage')).toBe(
        'Failed to load model with error: Failure!',
      );
    });

    it('error is logged in sentry', () => {
      expect(Sentry.captureException).toHaveBeenCalled();
    });
  });

  describe('with data', () => {
    it('does not show empty state', async () => {
      await createWrapper();

      expect(findEmptyState().exists()).toBe(false);
    });

    describe('header', () => {
      it('sets model metadata item to model count', async () => {
        await createWrapper();

        expect(findModelCountMetadataItem().text()).toContain('2 models');
      });
    });

    describe('shows models', () => {
      let resolver;

      beforeEach(async () => {
        resolver = jest.fn().mockResolvedValue(modelsQuery());
        await createWrapper({ resolver });
      });

      it('calls query only once on setup', () => {
        expect(resolver).toHaveBeenCalledTimes(1);
      });

      it('passes items to list', () => {
        expect(findSearchableTable().props('models')).toEqual([
          modelWithOneVersion,
          modelWithoutVersion,
        ]);
      });

      it('displays model rows', () => {
        expect(findSearchableTable().props('models')).toHaveLength(2);
      });
    });
  });
});
