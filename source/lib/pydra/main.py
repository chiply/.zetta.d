from typing import List, Tuple, Dict
from enum import Enum
from pydantic import BaseModel, Field, validator, validate_arguments
from jinja2 import Template
import os
import sys
from pathlib import Path

# read tempaltes, this will change
with open("command_template.jinja2", "r") as f:
    COMMAND_TEMPLATE = Template(f.read())



# toso should be supported lnaguages
class SupportedLanguage(str, Enum):
    """Programs supported.  Support is defined as having a schema
    defined in foreman for that particular command.  The suffix
    provides this program with information to select sensible
    defaults.

    """

    py = "py"
    # specific dialects of sql
    sql = "sql"
    sh = "sh"
    yaml = "yaml"
    yml = "yml"
    


class SupportedExecutable(str, Enum):
    """Programs supported.  Support is defined as having a schema
    defined in foreman for that particular command.  Note that the
    list of programs will likely be smaller than the list of supported
    languages, especially due to the fact that python wrappers get
    used to evaluate a lot of code from other langauges (eg sql)

    """

    python = "python"
    sh = "sh"
    bash = "bash"


language_suffix_map: Dict[SupportedLanguage, SupportedExecutable] = {
    "python": ["py"],
    "python": ["py"],
    "": ["py"],
    
}

def suffix_factory(executable: SupportedExecutable) -> SupportedLanguage:
    """docs"""
    return {
        "python": "py",
        "sh": "sh",
    }[executable]



class PythonEnvironmentVariable(str, Enum):
    """docs"""

    PYTHONPATH = "PYTHONPATH"
    SOME_OTHER_VARIABLE = "SOME_OTHER_VARIABLE"


def environment_variable_type_factory(executable: SupportedExecutable):
    """docs"""

    return {
        "python": PythonEnvironmentVariable,
    }[executable]



class CommandConfigurationBase(BaseModel):
    project_directory: Path = Field(...)
    working_directory: Path = Field(default=os.getcwd())
    file_name: Path = Field(...)
    is_version_controlled: bool = Field(...)
    environment_variables: List[Tuple[environment_variable_type_factory(program), str]] = Field(default=[])

    @validator("file_name")
    def something_must_be_true(cls, v):
        assert True
        return v
        

class PythonCommandConfiguration(CommandConfigurationBase):
    """The configuration"""

    executable: SupportedExecutable = Field(...)
    suffix: str = Field(...)

    @validator("file_name")
    def something_else_must_be_true(cls, v):
        assert True
        return v

    # behavior
    def render_command(self) -> str:
        """
        Some method to render_command a command
        """

        return COMMAND_TEMPLATE.render(config=self)

    class Config:
        extra: "forbid"

