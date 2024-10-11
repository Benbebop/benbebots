package components

type Components map[string]bool

func (c Components) IsEnabled(name string) bool {
	for n, e := range c {
		if n == name {
			return e
		}
	}
	return true
}
