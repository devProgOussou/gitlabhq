import { nextTick } from 'vue';

import NewEditForm from '~/organizations/shared/components/new_edit_form.vue';
import OrganizationUrlField from '~/organizations/shared/components/organization_url_field.vue';
import AvatarUploadDropzone from '~/vue_shared/components/upload_dropzone/avatar_upload_dropzone.vue';
import MarkdownField from '~/vue_shared/components/markdown/field.vue';
import { helpPagePath } from '~/helpers/help_page_helper';
import {
  FORM_FIELD_NAME,
  FORM_FIELD_ID,
  FORM_FIELD_PATH,
  FORM_FIELD_AVATAR,
} from '~/organizations/shared/constants';
import { mountExtended } from 'helpers/vue_test_utils_helper';

describe('NewEditForm', () => {
  let wrapper;

  const defaultProvide = {
    organizationsPath: '/-/organizations',
    rootUrl: 'http://127.0.0.1:3000/',
    previewMarkdownPath: '/-/organizations/preview_markdown',
  };

  const defaultPropsData = {
    loading: false,
  };

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = mountExtended(NewEditForm, {
      attachTo: document.body,
      provide: defaultProvide,
      propsData: {
        ...defaultPropsData,
        ...propsData,
      },
    });
  };

  const findNameField = () => wrapper.findByLabelText('Organization name');
  const findIdField = () => wrapper.findByLabelText('Organization ID');
  const findUrlField = () => wrapper.findComponent(OrganizationUrlField);
  const findDescriptionField = () => wrapper.findByLabelText('Organization description (optional)');
  const findAvatarField = () => wrapper.findComponent(AvatarUploadDropzone);

  const setUrlFieldValue = async (value) => {
    findUrlField().vm.$emit('input', value);
    await nextTick();
  };
  const submitForm = async () => {
    await wrapper.findByRole('button', { name: 'Create organization' }).trigger('click');
  };

  it('renders `Organization name` field', () => {
    createComponent();

    expect(findNameField().exists()).toBe(true);
  });

  it('renders `Organization URL` field', () => {
    createComponent();

    expect(findUrlField().exists()).toBe(true);
  });

  it('renders `Organization avatar` field', () => {
    createComponent();

    expect(findAvatarField().props()).toMatchObject({
      value: null,
      entity: { [FORM_FIELD_NAME]: '', [FORM_FIELD_PATH]: '', [FORM_FIELD_AVATAR]: null },
      label: 'Organization avatar',
    });
  });

  it('renders `Organization description` field as markdown editor', () => {
    createComponent();

    expect(findDescriptionField().exists()).toBe(true);
    expect(wrapper.findComponent(MarkdownField).props()).toMatchObject({
      markdownPreviewPath: defaultProvide.previewMarkdownPath,
      markdownDocsPath: helpPagePath('user/organization/index', {
        anchor: 'organization-description-supported-markdown',
      }),
      textareaValue: '',
      restrictedToolBarItems: [
        'code',
        'quote',
        'bullet-list',
        'numbered-list',
        'task-list',
        'collapsible-section',
        'table',
        'attach-file',
        'full-screen',
      ],
    });
  });

  describe('when `Organization avatar` field is changed', () => {
    const file = new File(['foo'], 'foo.jpg', {
      type: 'text/plain',
    });

    beforeEach(() => {
      window.URL.revokeObjectURL = jest.fn();
      createComponent();
      findAvatarField().vm.$emit('input', file);
    });

    it('updates `value` prop', () => {
      expect(findAvatarField().props('value')).toEqual(file);
    });
  });

  it('requires `Organization URL` field to be a minimum of two characters', async () => {
    createComponent();

    await setUrlFieldValue('f');
    await submitForm();

    expect(
      wrapper.findByText('Organization URL is too short (minimum is 2 characters).').exists(),
    ).toBe(true);
  });

  describe('when `fieldsToRender` prop is set', () => {
    beforeEach(() => {
      createComponent({ propsData: { fieldsToRender: [FORM_FIELD_ID] } });
    });

    it('only renders provided fields', () => {
      expect(findNameField().exists()).toBe(false);
      expect(findIdField().exists()).toBe(true);
      expect(findUrlField().exists()).toBe(false);
    });
  });

  describe('when `initialFormValues` prop is set', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          fieldsToRender: [FORM_FIELD_NAME, FORM_FIELD_ID, FORM_FIELD_PATH],
          initialFormValues: {
            [FORM_FIELD_NAME]: 'Foo bar',
            [FORM_FIELD_ID]: 1,
            [FORM_FIELD_PATH]: 'foo-bar',
          },
        },
      });
    });

    it('sets initial values for fields', () => {
      expect(findNameField().element.value).toBe('Foo bar');
      expect(findIdField().element.value).toBe('1');
      expect(findUrlField().props('value')).toBe('foo-bar');
    });
  });

  it('renders `Organization ID` field as disabled', () => {
    createComponent({ propsData: { fieldsToRender: [FORM_FIELD_ID] } });

    expect(findIdField().attributes('disabled')).toBe('disabled');
  });

  describe('when form is submitted without filling in required fields', () => {
    beforeEach(async () => {
      createComponent();
      await submitForm();
    });

    it('shows error messages', () => {
      expect(wrapper.findByText('Organization name is required.').exists()).toBe(true);
      expect(wrapper.findByText('Organization URL is required.').exists()).toBe(true);
    });
  });

  describe('when form is submitted successfully', () => {
    beforeEach(async () => {
      createComponent();

      await findNameField().setValue('Foo bar');
      await setUrlFieldValue('foo-bar');
      await findDescriptionField().setValue('Foo bar description');
      await submitForm();
    });

    it('emits `submit` event with form values', () => {
      expect(wrapper.emitted('submit')).toEqual([
        [{ name: 'Foo bar', path: 'foo-bar', description: 'Foo bar description', avatar: null }],
      ]);
    });
  });

  describe('when `Organization URL` has not been manually set', () => {
    beforeEach(async () => {
      createComponent();

      await findNameField().setValue('Foo bar');
      await submitForm();
    });

    it('sets `Organization URL` when typing in `Organization name`', () => {
      expect(findUrlField().props('value')).toBe('foo-bar');
    });
  });

  describe('when `Organization URL` has been manually set', () => {
    beforeEach(async () => {
      createComponent();

      await setUrlFieldValue('foo-bar-baz');
      await findNameField().setValue('Foo bar');
      await submitForm();
    });

    it('does not modify `Organization URL` when typing in `Organization name`', () => {
      expect(findUrlField().props('value')).toBe('foo-bar-baz');
    });
  });

  describe('when `Organization URL` field is not rendered', () => {
    beforeEach(async () => {
      createComponent({
        propsData: {
          fieldsToRender: [FORM_FIELD_NAME, FORM_FIELD_ID],
          initialFormValues: {
            [FORM_FIELD_NAME]: 'Foo bar',
            [FORM_FIELD_ID]: 1,
            [FORM_FIELD_PATH]: 'foo-bar',
          },
        },
      });

      await findNameField().setValue('Foo bar baz');
      await submitForm();
    });

    it('does not modify `Organization URL` when typing in `Organization name`', () => {
      expect(wrapper.emitted('submit')).toEqual([
        [{ name: 'Foo bar baz', id: 1, path: 'foo-bar' }],
      ]);
    });
  });

  describe('when `loading` prop is `true`', () => {
    beforeEach(() => {
      createComponent({ propsData: { loading: true } });
    });

    it('shows button with loading icon', () => {
      expect(wrapper.findByTestId('submit-button').props('loading')).toBe(true);
    });
  });

  describe('when `showCancelButton` prop is `false`', () => {
    beforeEach(() => {
      createComponent({ propsData: { showCancelButton: false } });
    });

    it('does not show cancel button', () => {
      expect(wrapper.findByRole('link', { name: 'Cancel' }).exists()).toBe(false);
    });
  });

  describe('when `showCancelButton` prop is `true`', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows cancel button', () => {
      expect(wrapper.findByRole('link', { name: 'Cancel' }).attributes('href')).toBe(
        defaultProvide.organizationsPath,
      );
    });
  });

  describe('when `submitButtonText` prop is not set', () => {
    beforeEach(() => {
      createComponent();
    });

    it('defaults to `Create organization`', () => {
      expect(wrapper.findByRole('button', { name: 'Create organization' }).exists()).toBe(true);
    });
  });

  describe('when `submitButtonText` prop is set', () => {
    beforeEach(() => {
      createComponent({ propsData: { submitButtonText: 'Save changes' } });
    });

    it('uses it for submit button', () => {
      expect(wrapper.findByRole('button', { name: 'Save changes' }).exists()).toBe(true);
    });
  });
});
