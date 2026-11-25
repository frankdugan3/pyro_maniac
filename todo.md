# To do

- **`humanize_field/1`.** It was documented as
  `PyroManiac.Presenter.humanize_field/1` but defined inside
  `defimpl PyroManiac.Presenter, for: Map`. It is now
  `PyroManiac.Presenter.Helpers.humanize_field/1`. Nothing calls it, and the
  renderers humanize field names in their own way. Use it in one place (the
  labels of fields without a `label`, in every renderer) or remove it.
