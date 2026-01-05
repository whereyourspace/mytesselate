from pytest import mark

from ansible_collections.tesselate.helpers.plugins.filter import (
    extract,
    format,
    to_dict,
    flatten_dict,
)


@mark.parametrize(['map', 'keys'],
    [
        ({'first_key': 'first_value', 'second_key': 'second_value', 'third_key': 'third_value'}, ['first_key', 'second_key']),
    ])
def test_extract(map, keys):
    rt = extract(map, keys)
    for key in keys:
        assert key in rt
        assert map[key] == rt[key]


@mark.parametrize(['str', 'map', 'expected'],
    [
        ('{first_key}:{second_key}', {'first_key': 'first_value', 'second_key': 'second_value'}, 'first_value:second_value')
    ])
def test_format(str, map, expected):
    actual = format(map, str)
    assert actual == expected


@mark.parametrize(['obj', 'key', 'attrs', 'expected'],
    [
        (1, "pos", { "prop_1" : "prop_1_v" }, { "pos" : 1, "prop_1" : "prop_1_v" }),
        ("str", "name", {}, { "name" : "str" } ),
    ])
def test_to_dict(obj, key, attrs, expected):
    assert to_dict(obj, key, attrs) == expected


@mark.parametrize(['map', 'parent_keys', 'expected'],
    [
        (
            {'city': 'moscow', 'country': 'russia'},
            [ ],
            [ 
                { 'key': 'city', 'value': 'moscow' },
                { 'key': 'country', 'value': 'russia' },
            ],
        ),
        (
            { 'city': 'moscow', 'shops': { 'name': 'coffee street', 'type': 'bar' } },
            [ ],
            [
                { 'key': 'city', 'value': 'moscow' },
                { 'key_0': 'shops', 'key': 'name', 'value': 'coffee street' },
                { 'key_0': 'shops', 'key': 'type', 'value': 'bar' },
            ]
        ),
        (
            { 'city': 'moscow', 'shops': { 'name': 'coffee street', 'type': 'bar' } },
            [ 'service' ],
            [
                { 'key': 'city', 'value': 'moscow' },
                { 'service': 'shops', 'key': 'name', 'value': 'coffee street' },
                { 'service': 'shops', 'key': 'type', 'value': 'bar' },
            ]
        )
    ])
def test_flatten_dict(map, parent_keys, expected):
    assert expected == flatten_dict(map, parent_keys)


@mark.parametrize(['map', 'parent_keys', 'key_name', 'value_name', 'expected'],
    [
        (
            { 'moscow': 'russia', 'new york city': 'usa', 'paris': 'france' },
            [ ],
            'city', 'country',
            [
                { 'city': 'moscow', 'country': 'russia' },
                { 'city': 'new york city', 'country': 'usa' },
                { 'city': 'paris', 'country': 'france' },
            ]
        )
    ])
def test_flatten_dict_key_value_names(map, parent_keys, key_name, value_name, expected):
    assert expected == flatten_dict(map, parent_keys, key_name, value_name)


@mark.parametrize(['map', 'parent_keys', 'expected'],
    [
        (
            { 'db': { 'name': 'test-db', 'users': [ 'test-user-one', 'test-user-two' ] } },
            [ 'component', 'privileges' ],
            [
                { 'component': 'db', 'key': 'name', 'value': 'test-db' },
                { 'component': 'db', 'privileges': 'users', 'key': 0, 'value': 'test-user-one' },
                { 'component': 'db', 'privileges': 'users', 'key': 1, 'value': 'test-user-two' },
            ]
        ),
    ])
def test_flatten_dict_with_list(map, parent_keys, expected):
    assert expected == flatten_dict(map, parent_keys)
