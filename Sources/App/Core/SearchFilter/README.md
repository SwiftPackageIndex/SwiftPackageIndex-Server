# Search Filters

Search filters are special keywords which can be inputted as part of the search query and will filter the results down
to only packages which match that filter.

Search filters do not apply to keyword or author results.

A search filter is a keyword in the format `<key>:<comparison><value>` where the key is one of the noted available filters
documented below.

If a search field is invalid (an unknown key or an invalid value type) then it is assumed that this is actually a search
term and will be expected in the package name/description in order to be shown in the results. For example, `stars:50`
will show all packages with 50 stars, but `stars:fifty` will only show packages with that phrase in the title or description.
This is because "fifty" is not a number, and thus is an invalid value type.

## Available Comparison Indicators

* Greater than: `>`
* Greater than or equal to: `>=`
* Less than: `<`
* Less than or equal to: `<=`
* Not equals to: `!`
* Equals to: no prefix required

## Available Filters

| Key   | Supported Comparison Methods | Value Requirements |
| ----- | ---------------------------- | ------------------ |
| stars         | > >= < <= = ! | a number |
| last_activity | > >= < <= = ! | a date in format YYYY-MM-DD |
| last_commit   | > >= < <= = ! | a date in format YYYY-MM-DD |
| license       | = !           | 'compatible' or the raw value of any known license (License.swift) |

> Note: I use `=` here to indicate an "equal to" comparison method. In reality you do not include a comparison indicator
> value. For example you would write `stars:500` not `stars:=500`. 
