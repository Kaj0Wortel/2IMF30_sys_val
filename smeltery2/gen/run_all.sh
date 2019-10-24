#!/bin/bash

echo $(ls "../properties" | cut -d'.' -f 1)
