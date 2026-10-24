import os
import sys
from pathlib import Path
from dotenv import load_dotenv
from datetime import timedelta
from os import getenv
import dj_database_url
load_dotenv()

# True quand la suite tourne sous pytest (settings importés par pytest-django).
RUNNING_TESTS = 'pytest' in sys.modules


BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.getenv('DJANGO_SECRET_KEY', 'django-insecure-1s8dnyc-opvm@#(otrc*as$q7ugiynv-$fbz$9b)@-&x2nr-vm')
DEBUG = os.getenv('DJANGO_DEBUG', 'True') == 'True'
ALLOWED_HOSTS = os.getenv('DJANGO_ALLOWED_HOSTS', '*').split(',')

# Application definition

INSTALLED_APPS = [
    'jazzmin',  # Pour une interface d'administration plus elegante
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework', # Django REST Framework pour construire une API RESTful
    'rest_framework_simplejwt',
    'rest_framework_simplejwt.token_blacklist', 
    'corsheaders',  # Pour gérer les CORS dans le cas où on a un frontend séparé (Angular/Flutter)
    'apps.users',   # Mon app de gestion des utilisateurs
    'apps.tontines', # Mon app de gestion des tontines
    'apps.paiements', # Mon app de gestion des paiements
    'apps.notifications', # Mon app de gestion des notifications
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',  # Middleware pour servir les fichiers statiques en production
    'django.contrib.sessions.middleware.SessionMiddleware',
    'corsheaders.middleware.CorsMiddleware',  # Middleware pour gérer les CORS dans le cas où on a un frontend séparé (Angular/Flutter)
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'apps.users.middleware.KeycloakMiddleware',   # Ici je mets mon middleware de Keycloak pour gérer l'authentification

]

ROOT_URLCONF = 'vTontine.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'vTontine.wsgi.application'


# Database
# https://docs.djangoproject.com/en/6.0/ref/settings/#databases

# DATABASES = {
#     'default': {
#         'ENGINE': 'django.db.backends.sqlite3',
#         'NAME': BASE_DIR / 'db.sqlite3',
#     }
# }

# Base de données PostgreSQL 

# Replace the DATABASES section of your settings.py with this
DATABASE_URL = getenv("DATABASE_URL")
if DATABASE_URL:
    DATABASES = {
        "default": dj_database_url.parse(
            DATABASE_URL,
            conn_max_age=600,
            ssl_require=getenv("DB_SSL_REQUIRE", "True") == "True",
        )
    }
else:
    # Repli local : variables DB_* (voir .env.example)
    DATABASES = {
        "default": {
            "ENGINE": getenv("DB_ENGINE", "django.db.backends.postgresql"),
            "NAME": getenv("DB_NAME", "tontine_db"),
            "USER": getenv("DB_USER", ""),
            "PASSWORD": getenv("DB_PASSWORD", ""),
            "HOST": getenv("DB_HOST", "localhost"),
            "PORT": getenv("DB_PORT", "5432"),
        }
    }




# Password validation
# https://docs.djangoproject.com/en/6.0/ref/settings/#auth-password-validators

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]


# Internationalization
# https://docs.djangoproject.com/en/6.0/topics/i18n/

LANGUAGE_CODE = 'en-us'

TIME_ZONE = 'UTC'

USE_I18N = True

USE_TZ = True


# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/6.0/howto/static-files/

# Fichiers médias (photos de profil, etc.)
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

STORAGES = {
    "default": {
        "BACKEND": "django.core.files.storage.FileSystemStorage",
    },
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
    },
}
# Django REST Framework
# REST_FRAMEWORK = {
#     'DEFAULT_AUTHENTICATION_CLASSES': [
#         'apps.users.authentication.KeycloakAuthentication',
#     ],
#     'DEFAULT_PERMISSION_CLASSES': [
#         'rest_framework.permissions.IsAuthenticated',
#     ],
#     # ScopedRateThrottle n'agit que sur les vues qui déclarent explicitement
#     # un `throttle_scope` (les autres ne sont pas affectées). Utilisé pour
#     # limiter le brute-force sur les endpoints d'authentification.
#     'DEFAULT_THROTTLE_CLASSES': [
#         'rest_framework.throttling.ScopedRateThrottle',
#     ],
#     'DEFAULT_THROTTLE_RATES': {
#         'auth_login': '5/min',
#         'auth_register': '5/min',
#         'auth_refresh': '30/min',
#         'auth_change_password': '5/min',
#     },
# }

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.ScopedRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'auth_register': '10/hour',
        'auth_login': '20/hour',
        'auth_refresh': '60/hour',
        'auth_change_password': '10/hour',
    },
}

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(hours=1),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'UPDATE_LAST_LOGIN': True,
    'AUTH_HEADER_TYPES': ('Bearer',),
    'USER_ID_FIELD': 'id',
    'USER_ID_CLAIM': 'user_id',
}

# Ma configuration de  Keycloak
KEYCLOAK_CONFIG = {
    'SERVER_URL': os.getenv('KEYCLOAK_SERVER_URL', 'http://127.0.0.1:8080'),
    'REALM': os.getenv('KEYCLOAK_REALM', 'tontine-realm'),
    'CLIENT_ID': os.getenv('KEYCLOAK_CLIENT_ID', 'tontine-client'),
    'CLIENT_SECRET': os.getenv('KEYCLOAK_CLIENT_SECRET', '4JZ9X4EQS2XA8Tk6dvDxRzdiPg1Am9Vl'),
    # Compte admin du realm master (pour créer/mettre à jour les users)
    'ADMIN_USER': os.getenv('KEYCLOAK_ADMIN_USER', 'admin'),
    'ADMIN_PASSWORD': os.getenv('KEYCLOAK_ADMIN_PASSWORD', 'admin'),
}
 
# CORS (pour frontend React/Vue)
CORS_ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://localhost:5173",
]

# URL publique du frontend (utilisée pour construire les liens d'invitation partageables)
FRONTEND_URL = os.getenv('FRONTEND_URL', 'https://vtontine.app').rstrip('/')

# Vérification IA des captures d'écran de paiement (Gemini). Si absente, la
# vérification est simplement ignorée (statut 'NON_VERIFIE').
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY', '')

AUTH_USER_MODEL = 'users.User'