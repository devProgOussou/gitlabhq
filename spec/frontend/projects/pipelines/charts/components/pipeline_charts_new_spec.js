import { GlCollapsibleListbox } from '@gitlab/ui';
import { GlSingleStat } from '@gitlab/ui/dist/charts';
import { shallowMount, mount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { getDateInPast } from '~/lib/utils/datetime_utility';
import PipelineChartsNew from '~/projects/pipelines/charts/components/pipeline_charts_new.vue';
import StatisticsList from '~/projects/pipelines/charts/components/statistics_list.vue';
import PipelineDurationChart from '~/projects/pipelines/charts/components/pipeline_duration_chart.vue';
import PipelineStatusChart from '~/projects/pipelines/charts/components/pipeline_status_chart.vue';
import getPipelineAnalyticsQuery from '~/projects/pipelines/charts/graphql/queries/get_pipeline_analytics.query.graphql';
import { createAlert } from '~/alert';
import { useFakeDate } from 'helpers/fake_date';
import { pipelineAnalyticsEmptyData, pipelineAnalyticsData } from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');

const projectPath = 'gitlab-org/gitlab';

describe('~/projects/pipelines/charts/components/pipeline_charts_new.vue', () => {
  useFakeDate();

  let wrapper;
  let getPipelineAnalyticsHandler;

  const findGlCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findStatisticsList = () => wrapper.findComponent(StatisticsList);
  const findPipelineDurationChart = () => wrapper.findComponent(PipelineDurationChart);
  const findPipelineStatusChart = () => wrapper.findComponent(PipelineStatusChart);
  const findAllSingleStats = () => wrapper.findAllComponents(GlSingleStat);

  const createComponent = ({ mountFn = shallowMount } = {}) => {
    wrapper = mountFn(PipelineChartsNew, {
      provide: {
        projectPath,
      },
      apolloProvider: createMockApollo([[getPipelineAnalyticsQuery, getPipelineAnalyticsHandler]]),
    });
  };

  beforeEach(() => {
    getPipelineAnalyticsHandler = jest.fn();
  });

  it('creates an alert on error', async () => {
    getPipelineAnalyticsHandler.mockRejectedValue();
    createComponent({});

    await waitForPromises();

    expect(createAlert).toHaveBeenCalledWith({
      message:
        'An error occurred while loading pipeline analytics. Please try refreshing the page.',
    });
  });

  describe('date range', () => {
    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('is "Last 7 days" by default', () => {
      expect(findGlCollapsibleListbox().props('selected')).toBe(7);

      expect(getPipelineAnalyticsHandler).toHaveBeenCalledTimes(1);
      expect(getPipelineAnalyticsHandler).toHaveBeenLastCalledWith({
        fullPath: projectPath,
        fromTime: getDateInPast(new Date(), 7),
        toTime: new Date(),
      });
    });

    it('is set when an option is selected', async () => {
      findGlCollapsibleListbox().vm.$emit('select', 90);

      await waitForPromises();

      expect(getPipelineAnalyticsHandler).toHaveBeenCalledTimes(2);
      expect(getPipelineAnalyticsHandler).toHaveBeenLastCalledWith({
        fullPath: projectPath,
        fromTime: getDateInPast(new Date(), 90),
        toTime: new Date(),
      });
    });
  });

  describe('statistics', () => {
    it('renders loading state', () => {
      createComponent();

      expect(findStatisticsList().props('loading')).toEqual(true);
    });

    it('renders with empty data', async () => {
      getPipelineAnalyticsHandler.mockResolvedValue(pipelineAnalyticsEmptyData);

      createComponent({ mountFn: mount });
      await waitForPromises();

      expect(findStatisticsList().props('counts')).toEqual({
        failureRatio: 0,
        medianDuration: 0,
        successRatio: 0,
        total: '0',
      });

      expect(findAllSingleStats().at(0).text()).toBe('Total pipeline runs 0');
      expect(findAllSingleStats().at(1).text()).toBe('Failure rate 0%');
      expect(findAllSingleStats().at(2).text()).toBe('Success rate 0%');
    });

    it('renders with data', async () => {
      getPipelineAnalyticsHandler.mockResolvedValue(pipelineAnalyticsData);

      createComponent({ mountFn: mount });

      await waitForPromises();

      expect(findStatisticsList().props('counts')).toEqual({
        failureRatio: 25,
        medianDuration: 1800,
        successRatio: 25,
        total: '8',
      });

      expect(findAllSingleStats().at(0).text()).toBe('Total pipeline runs 8');
      expect(findAllSingleStats().at(1).text()).toBe('Median duration 30m');
      expect(findAllSingleStats().at(2).text()).toBe('Failure rate 25%');
      expect(findAllSingleStats().at(3).text()).toBe('Success rate 25%');
    });
  });

  describe('charts', () => {
    it('renders loading state with no charts', () => {
      createComponent();

      expect(findPipelineDurationChart().props()).toEqual({ loading: true, timeSeries: [] });
      expect(findPipelineDurationChart().props()).toEqual({ loading: true, timeSeries: [] });
    });

    it('renders with data', async () => {
      getPipelineAnalyticsHandler.mockResolvedValue(pipelineAnalyticsData);

      createComponent();
      await waitForPromises();

      expect(findPipelineDurationChart().props('timeSeries')).toEqual(
        pipelineAnalyticsData.data.project.pipelineAnalytics.timeSeries,
      );
      expect(findPipelineStatusChart().props('timeSeries')).toEqual(
        pipelineAnalyticsData.data.project.pipelineAnalytics.timeSeries,
      );
    });
  });
});
