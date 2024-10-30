# NOTE: this app has been designed as a demo, NOT a template for production.
# There are more complete reference apps at the Elastic Search-Labs repo: https://github.com/elastic/elasticsearch-labs
import datetime
import uuid
from datetime import timezone, datetime
import streamlit as st
from elasticsearch import Elasticsearch
import os
import math
import tiktoken
import pandas as pd
from langchain_community.llms import Ollama

from langchain.schema import (
    SystemMessage,
    HumanMessage,
)
import time
from PIL import Image
# connection to Elasticsearch and define the specific parameters used in the app
es = Elasticsearch("http://localhost:9200", basic_auth=("elastic", os.environ['ES_LOCAL_PASSWORD']))
report_index = 'search-reports'
report_pipeline = 'ml-inference-search-reports'
transformer_model = '.elser_model_2_linux-x86_64'
logging_index = 'llm_interactions'
logging_pipeline = 'ml-inference-llm_logging'

BASE_URL = "http://localhost:11434"


def init_chat_model():
    llm = Ollama(model=os.environ['MODEL'])
    return llm

# perform a semantic and bm25 keyword search on a specific report
def report_search(index, question, report_name):
    model_id = transformer_model
    query = {
        "bool": {
            "should": [
                {
                    "text_expansion": {
                        "ml.inference.text_expanded.predicted_value": {
                            "model_id": model_id,
                            "model_text": question
                        }
                    }
                },
                {
                    "match": {
                        "text": question
                    }
                }
            ],
            "filter": {
                "term": {
                    "report_name.keyword": report_name
                }
            }
        }
    }

    field_list = ['page', 'text', '_score']
    results = es.search(index=index, query=query, size=100, fields=field_list, min_score=5)
    response_data = [{"_score": hit["_score"], **hit["_source"]} for hit in results["hits"]["hits"]]
    documents = []
    # Check if there are hits
    if "hits" in results and "total" in results["hits"]:
        total_hits = results["hits"]["total"]
        # Check if there are any hits with a value greater than 0
        if isinstance(total_hits, dict) and "value" in total_hits and total_hits["value"] > 0:
            for hit in response_data:
                doc_data = {field: hit[field] for field in field_list if field in hit}
                documents.append(doc_data)
    return documents


# aggregate the names of all reports stored in the index
def get_reports(index):
    aggregation_query = {
        "size": 0,
        "query": {
            "match_all": {
            }
        },
        "aggs": {
            "reports": {
                "terms": {
                    "field": "report_name.keyword",
                    "size": 1000
                }
            }
        }
    }
    reports = es.search(index=index, body=aggregation_query)
    buckets = reports['aggregations']['reports']['buckets']
    report_list = []
    for bucket in buckets:
        key = bucket['key']
        report_list.append(key)
    return report_list


def construct_prompt(question, results):
    for record in results:
        if "_score" in record:
            del record["_score"]
    result = ""
    for item in results:
        result += f"Page: {item['page']} , Text: {item['text']}\n"

    # interact with the LLM
    augmented_prompt = f"""Using only the context below, answer the query.
    Context: {result}
    Query: {question}"""
    messages = [
        SystemMessage(
            content="You are a helpful analyst that answers questions based only on the context provided. "
                    "When you respond, please cite your source and where possible, always summarise your answers."),
        HumanMessage(content=augmented_prompt)
    ]
    return messages


def check_qa_log(question, report_name):
    model_id = transformer_model
    query = {
        "bool": {
            "should": [
                {
                    "text_expansion": {
                        "ml.inference.question_expanded.predicted_value": {
                            "model_id": model_id,
                            "model_text": question
                        }
                    }
                },
                {
                    "match": {
                        "question": question
                    }
                }
            ],
            "must": [{
                "term": {
                    "report_name.keyword": report_name
                },
                "term": {
                    "answer_type.keyword": "original"
                }
            }]
        }
    }
    results = es.search(index=logging_index, query=query, size=1, min_score=20)
    if results['hits']['total']['value'] > 0:
        answer_value = results['hits']['hits'][0]['_source']['answer']
    else:
        answer_value = 0
    return answer_value

def common_questions(report_name):
    aggregation_query = {
        "size": 0,
        "query": {
            "term": {
                "report_name": report_name
            }
        },
        "aggs": {
            "questions": {
                "terms": {
                    "field": "question.keyword",
                    "size": 10
                }
            }
        }
    }
    questions = es.search(index=logging_index, body=aggregation_query)
    buckets = questions['aggregations']['questions']['buckets']
    question_list = []
    for bucket in buckets:
        key = bucket['key']
        question_list.append(key)
    return question_list


# search form
image = Image.open('images/logo_1.png')
st.image(image, width=150)
st.title("RAGoldberg")
st.header("Search a report")
report_source = st.selectbox("Choose your annual report", get_reports(report_index))
question = st.text_input("Question", placeholder="What would you like to know?")
submitted = st.button("search")
if report_source:
    question_list = common_questions(report_source)
    if len(question_list):
        with st.expander("Common questions"):
            for i in question_list:
                st.markdown(f"{i}")

if submitted:
    chat_model = init_chat_model()
    existing_answer = check_qa_log(question, report_source)
    results = report_search(report_index, question, report_source)
    df_results = pd.DataFrame(results)
    with st.status("Searching the data...") as status:
        status.update(label=f'Retrieved {len(results)} results from Elasticsearch', state="running")
    with st.chat_message("ai assistant", avatar="🤖"):
        full_response = ""
        message_placeholder = st.empty()
        sent_time = datetime.now(tz=timezone.utc)
        prompt = construct_prompt(question, results)
        if existing_answer == 0:
            current_chat_message = chat_model(prompt).content
            answer_type = 'original'
        else:
            current_chat_message = existing_answer
            answer_type = 'existing'
        for chunk in current_chat_message.split():
            full_response += chunk + " "
            time.sleep(0.05)
            # Add a blinking cursor to simulate typing
            message_placeholder.markdown(full_response + "▌")
        message_placeholder.markdown(full_response)
        # chat_bot.info(current_chat_message)
        received_time = datetime.now(tz=timezone.utc)
        status.update(label="AI response complete!", state="complete")
    # st.write(construct_prompt(question, results))
    string_prompt = str(prompt)
    st.dataframe(df_results)
