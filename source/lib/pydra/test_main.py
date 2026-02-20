import pytest
import os
from typing import List, Tuple
from hypothesis import given, example, strategies as st
from unittest import mock

from hypothesis_jsonschema import from_schema
from main import create_configuration_class
import sys
import pprint
pp = pprint.PrettyPrinter(indent=4)



# get schema
configuration_python_model = create_configuration_class("python")
configuration_python_model_schema = configuration_python_model.schema()

with open("output.json", "w") as f:
    f.write(configuration_python_model.schema_json())


@given(
    configuration_python_object=from_schema(
        configuration_python_model_schema,
        # provides sample values for formats specified in the JSON schema
        custom_formats={
            "path": st.sampled_from(
                [
                    "/some/directory",
                    "/some/other/directory",
                ]
            ),
        },
    )
)
def test_configuration_python_render(configuration_python_object):
    # Arrange
    pp.pprint(configuration_python_object)
    # Act
    # LEFTOFF -- method to print json
    command = configuration_python_model(**configuration_python_object).render_command()
    # Assert
    print(command)
    #assert isinstance(command, str)
    print('\n\n')
    assert True


