package main

# Policy as Code para el Dockerfile del proyecto (Conftest / OPA).
# deny = incumplimiento, warn = recomendacion.

from_images contains image if {
	some i
	input[i].Cmd == "from"
	image := input[i].Value[0]
}

stage_aliases contains alias if {
	some i
	input[i].Cmd == "from"
	count(input[i].Value) == 3
	alias := lower(input[i].Value[2])
}

external_images contains image if {
	some image in from_images
	not lower(image) in stage_aliases
}

deny contains msg if {
	some image in external_images
	not contains(image, ":")
	msg := sprintf("La imagen base '%s' no declara una version (tag)", [image])
}

deny contains msg if {
	some image in external_images
	endswith(image, ":latest")
	msg := sprintf("La imagen base '%s' usa el tag 'latest'", [image])
}

warn contains msg if {
	some image in external_images
	not contains(image, "@sha256:")
	msg := sprintf("La imagen base '%s' no esta fijada por digest (@sha256)", [image])
}

runtime_image := image if {
	froms := [input[i].Value[0] | some i; input[i].Cmd == "from"]
	image := froms[count(froms) - 1]
}

deny contains msg if {
	contains(lower(runtime_image), "jdk")
	msg := sprintf("La imagen final '%s' incluye el JDK completo; usar una imagen JRE reduce la superficie de ataque", [runtime_image])
}

users := [input[i].Value[0] | some i; input[i].Cmd == "user"]

deny contains msg if {
	count(users) == 0
	msg := "El Dockerfile no define la instruccion USER; el contenedor se ejecutaria como root"
}

deny contains msg if {
	count(users) > 0
	last := lower(users[count(users) - 1])
	last in {"root", "0", "root:root", "0:0"}
	msg := "El ultimo USER del Dockerfile es root"
}

deny contains msg if {
	some i
	input[i].Cmd == "add"
	msg := sprintf("Se usa ADD (%s); preferir COPY", [concat(" ", input[i].Value)])
}

deny contains msg if {
	some i
	input[i].Cmd in {"env", "arg"}
	some value in input[i].Value
	regex.match(`(?i)(password|passwd|secret|token|api[_-]?key)`, value)
	msg := sprintf("Posible secreto declarado en %s: %s", [upper(input[i].Cmd), value])
}

warn contains msg if {
	count([i | some i; input[i].Cmd == "healthcheck"]) == 0
	msg := "El Dockerfile no define HEALTHCHECK"
}
