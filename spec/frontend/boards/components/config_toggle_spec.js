import { shallowMount } from '@vue/test-utils';
import { GlButton } from '@gitlab/ui';
import { __ } from '~/locale';
import ConfigToggle from '~/boards/components/config_toggle.vue';
import eventHub from '~/boards/eventhub';
import { mockTracking } from 'helpers/tracking_helper';

describe('ConfigToggle', () => {
  let wrapper;

  const createComponent = (provide = {}, props = {}) =>
    shallowMount(ConfigToggle, {
      provide: {
        canAdminList: true,
        ...provide,
      },
      propsData: props,
    });

  const findButton = () => wrapper.findComponent(GlButton);

  it('renders a button with label `View scope` when `canAdminList` is `false`', () => {
    wrapper = createComponent({ canAdminList: false });
    expect(findButton().text()).toBe('View scope');
  });

  it('renders a button with label `Edit board` when `canAdminList` is `true`', () => {
    wrapper = createComponent();
    expect(findButton().text()).toBe('Edit board');
  });

  it('emits `showBoardModal` when button is clicked', () => {
    const eventHubSpy = jest.spyOn(eventHub, '$emit');
    wrapper = createComponent();

    findButton().vm.$emit('click', { preventDefault: () => {} });

    expect(eventHubSpy).toHaveBeenCalledWith('showBoardModal', 'edit');
  });

  it('tracks clicking the button', () => {
    const trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
    wrapper = createComponent();

    findButton().vm.$emit('click', { preventDefault: () => {} });

    expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_button', {
      label: 'edit_board',
    });
  });

  it.each`
    boardHasScope
    ${true}
    ${false}
  `('renders dot highlight and tooltip depending on boardHasScope prop', ({ boardHasScope }) => {
    wrapper = createComponent({}, { boardHasScope });

    expect(findButton().classes('dot-highlight')).toBe(boardHasScope);

    if (boardHasScope) {
      expect(findButton().attributes('title')).toBe(__("This board's scope is reduced"));
    } else {
      expect(findButton().attributes('title')).toBe('');
    }
  });
});
