#!/usr/bin/python

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import sys
import tempfile
import numpy as np
import time

import csv
import collections

from itertools import izip
import os

root = os.environ['MR_ROOT']
sys.path.insert(0,root + '/Libs/Internal/MedPyExport/generate_binding/Release/rh-python27')
#sys.path.insert(0,'/nas1/UsersData/avi/MR/Libs/Internal/MedPyExport/generate_binding/Release/rh-python27')
import med

FLAGS = None

# Write to file
def write_to_file(header,samples,data,file_name):

	with open(file_name, "wb") as output:
		writer = csv.writer(output, lineterminator='\n')
		writer.writerow(header)

	# identify serial + id columns
	serial_col = -1
	id_col = -1
	for i in range(len(header)):
		if (header[i] == 'serial'):
			serial_col = i
		elif (header[i] == 'id'):
			id_col = i

	if (id_col == -1):
		raise ValueError("Cannot find id in header")
	if (serial_col == -1):
		raise ValueError("Cannot find serial in header")

	out_samples = np.zeros((data.shape[0],samples.shape[1]))
	out_samples[:,id_col] = np.arange(out_samples.shape[0])
	out_samples[:,serial_col] = out_samples[:,id_col]
	for i in range(samples.shape[1]):
		if (i != id_col and i != serial_col):
			out_samples[:,i] = samples[0,i]

	matrix = np.concatenate((out_samples, data), axis=1)
	with open(file_name, 'ab') as outpout:
		np.savetxt(outpout, matrix, delimiter=",",fmt='%f')

# Data
Datasets = collections.namedtuple('Datasets', ['train', 'test'])

class DataSet(object):

	# Initialization of a data set
	def __init__(self, data, header, treatment_name, name=None):

		features_cols = []
		samples_cols = []
		label_col = -1
		weights_col = -1
		treatments_col = -1
		
		for col in range(len(header)):
			if (header[col] == "outcome"):
				label_col = col
				samples_cols.append(col)
			elif (header[col] == "weight" or header[col] == "attr_train_weight"):
				weights_col = col
				samples_cols.append(col)
			elif (header[col] == treatment_name):
				treatments_col = col
			elif (header[col] != "serial" and header[col] != "id" and header[col] != "time" and header[col] != "outcome_time" and header[col] != "outcomeTime" and header[col] != "split" and header[col][:5] != "pred_"):
				features_cols.append(col)
			else:
				samples_cols.append(col)

		print(label_col,weights_col,features_cols,samples_cols,treatments_col)
		self.features = np.array(data[:,features_cols])
		self.qfeatures = np.array(data[:,features_cols], dtype=int)
		self.exists_mask = np.array(data[:,features_cols], dtype=float)
		self.labels = np.array(data[:,label_col]).reshape([-1,1])
		self.weights = np.array(data[:,weights_col]).reshape([-1,1])
		self.treatment = np.array(data[:,treatments_col])
		self.samples = np.array(data[:,samples_cols])

		self.nfeatures = len(features_cols)
		self.num_examples = len(data)
		self.header = header
		self.samples_header = [header[i] for i in samples_cols]
		self.feature_names = [header[i] for i in features_cols]
		
		self.features_mean = self.features.mean(axis=0)
		self.features_std = self.features.std(axis=0)
		for i in range(len(self.features_std)):
			if (self.features_std[i] == 0):
				self.features_std[i] = 1.0 ;

		self._epochs_completed = 0
		self._index_in_epoch = 0
		
	# Restart batching
	def init_batches(self):
		self._index_in_epoch = 0
				
	# Generate next batch
	def next_batch(self, batch_size,shuffle=True):
		start = self._index_in_epoch
		# Shuffle for the first epoch
		if self._epochs_completed == 0 and start == 0:
			perm0 = np.arange(self.num_examples)
			if (shuffle):
				np.random.shuffle(perm0)
			perm1 = np.arange(self.num_examples)
			np.random.shuffle(perm1)
			self._features = self.features[perm0]
			self._qfeatures = self.qfeatures[perm0]
			self._exists_mask = self.exists_mask[perm0]
			self._random_exists_mask = self.exists_mask[perm1]
			self._labels = self.labels[perm0]
			self._weights = self.weights[perm0]
			self._treatment = self.treatment[perm0]
		# Go to the next epoch
		if start + batch_size > self.num_examples:
			# Finished epoch
			self._epochs_completed += 1
			# Get the rest examples in this epoch
			rest_num_examples = self.num_examples - start
			features_rest_part = self._features[start:self.num_examples]
			qfeatures_rest_part = self._qfeatures[start:self.num_examples]
			exists_mask_rest_part = self._exists_mask[start:self.num_examples]
			random_exists_mask_rest_part = self._random_exists_mask[start:self.num_examples]
			labels_rest_part = self._labels[start:self.num_examples]
			weights_rest_part = self._weights[start:self.num_examples]
			treatment_rest_part = self._treatment[start:self.num_examples]
			# Shuffle the data
			if shuffle:
				perm = np.arange(self.num_examples)
				np.random.shuffle(perm)
				self._features = self.features[perm]
				self._qfeatures = self.qfeatures[perm]
				self._exists_mask = self.exists_mask[perm]
				self._labels = self.labels[perm]
				self._weights = self.weights[perm]
				self._treatment = self.treatment[perm]
			perm_r = np.arange(self.num_examples)
			np.random.shuffle(perm_r)
			self._random_exists_mask = self.exists_mask[perm_r]
			# Start next epoch
			start = 0
			self._index_in_epoch = batch_size - rest_num_examples
			end = self._index_in_epoch
			features_new_part = self._features[start:end]
			qfeatures_new_part = self._qfeatures[start:end]
			exists_mask_new_part = self._exists_mask[start:end]
			random_exists_mask_new_part = self._random_exists_mask[start:end]
			labels_new_part = self._labels[start:end]
			weights_new_part = self._weights[start:end]
			treatment_new_part = self._treatment[start:end]
			return np.concatenate((features_rest_part, features_new_part), axis=0) , np.concatenate((labels_rest_part, labels_new_part), axis=0) \
				, np.concatenate((weights_rest_part, weights_new_part), axis=0), np.concatenate((treatment_rest_part, treatment_new_part), axis=0) \
				, np.concatenate((qfeatures_rest_part, qfeatures_new_part), axis=0) , np.concatenate((exists_mask_rest_part, exists_mask_new_part), axis=0) \
				, np.concatenate((random_exists_mask_rest_part, random_exists_mask_new_part), axis=0)
		else:
			self._index_in_epoch += batch_size
			end = self._index_in_epoch
			return self._features[start:end], self._labels[start:end], self._weights[start:end], self._treatment[start:end], self._qfeatures[start:end], self._exists_mask[start:end] , self._random_exists_mask[start:end]

	# Write to file
	def write_to_file(self,file_name):
		write_to_file(self.header,self.samples,self.features,file_name)

	def prep_exists_mask(self, missing_value):
		self.exists_mask = (self.features != missing_value).astype(float)
		
	def quantize(self, maxq, max_big):
		
		"""
		for col in range(data.features.shape[1]):
			print("quantizing col %d\n" % col)
			vals, counts = np.unique(data.features[:,col], return_counts=True)
			print(vals, counts)
		"""	
		outData = []
		dataT = self.features.T
		for idx,column in enumerate(dataT):
			uvals, ucounts = np.unique(column, return_counts=True)
			bound = float(column.size)/(float(maxq)/1.0)
			
			"""
			uinds = np.argsort(-ucounts)
			vh = np.zeros(uvals.size)
			if (uinds.size >= max_big):
				for i in range(max_big):
					if (ucounts[uinds[i]] > bound):
						vh[uinds[i]] = i+1
			else:
				for i in range(uinds.size):
					if (ucounts[uinds[i]] > bound):
						vh[uinds[i]] = i+1
				
			vdict = dict(izip(uvals,vh))
			indices = np.vectorize(vdict.get)(column)
			"""
			gtb = np.nonzero(ucounts>bound)
			vgtb = uvals[gtb[0]]
			print("idx %d size %d bound %f gtb %d\n" % (idx, uvals.size, bound, gtb[0].size))
			
			
			if (uvals.size <= maxq):
				qvals = uvals
			else:
				vbig = np.unique(np.concatenate((uvals[gtb[0]], uvals[gtb[0]+1]), 0))
				mq = maxq - vbig.size
				vmin = np.min(column)
				minv = vmin
				if (minv < -4.0):
					minv = -4.0
				vmax = np.max(column)
				maxv = vmax
				if (maxv > 4.0):
					maxv = 4.0
				delta = (maxv - minv)/mq
				vals = np.arange(minv, maxv + delta + 0.001, delta)
				vals[0] = vmin-0.001
				vals[-1] = vmax + delta + 0.001
				qvals = np.unique(np.concatenate((vals, vbig), 0))
				print("vbig %d vals %d qvals %d\n" % (vbig.size, vals.size, qvals.size))
			indices = np.searchsorted(qvals, column, side='right') - 1
			
			# indices = np.isin(column, vgtb)
			outData.append(indices.astype(int))
		self.qfeatures = np.array(outData).T			

# Read csv from file
def read_csv_data_set(file, treatment_name):
	print("Reading csv file %s"%file)

	header = []
	list = []
	with open(file) as csv_file:
		data_file = csv.reader(csv_file)
		for row in data_file:
			if (len(header)==0):
				header = row
			else:
				list.append(row)
	print("Arranging")
	data = np.array(list).astype(float)
	return DataSet(data,header,treatment_name)

def read_and_split_csv_data_set(file, prob, treatment_name):
	print("Reading csv file %s"%file)

	header = []
	list1 = []
	list2 = []
	dict = {}
	with open(file) as csv_file:
		data_file = csv.reader(csv_file)
		for row in data_file:
			if (len(header)==0):
				header = row
			else:
				if (row[1] in dict):
					if (dict[row[1]] == 1):
						list1.append(row)
					else:
						list2.append(row)
				else:
				
					if (np.random.rand() > prob):
						list1.append(row)
						dict[row[1]] = 1
					else:
						list2.append(row)
						dict[row[1]] = 2
						dict[row[1]] = 2
	print("Arranging")
	data1 = np.array(list1).astype(float)
	data2 = np.array(list2).astype(float)
	return DataSet(data1,header,treatment_name),DataSet(data2,header,treatment_name)

# Read Data set and split to train and test
def read_and_split_data_set(data_file, test_p, treatment_name):

	# Read
	train,test = read_and_split_csv_data_set(data_file,test_p,treatment_name)
	
	print("Train",train.features.shape,train.labels.shape,train.weights.shape,train.treatment.shape)
	print("Test",test.features.shape,test.labels.shape,test.weights.shape,test.treatment.shape)
	
	return Datasets(train=train,test=test)
	
# Read a signle dataset
def read_data_set(data_file, treatment_name):

	# Read
	test = read_csv_data_set(data_file,treatment_name)
	
	print("Data",test.features.shape,test.labels.shape,test.weights.shape,test.treatment.shape)
	
	return test

def prep_data_sets_from_features(features,treatment_name,p_test):

	fsamples = med.Samples()
	fsamples.import_from_sample_vec(features.samples)
	df_samples = fsamples.to_df()

	# Split to train + test
	ids = np.unique(df_samples['id'])
	np.random.shuffle(ids)
	test_ids = np.resize(ids, [int(len(ids)*p_test)])
	test_inds = np.isin(df_samples['id'],test_ids)

	# Columns
	sample_col_names = list(df_samples.columns)
	feature_names = list(features.get_feature_names())
	ncols = 1 + len(sample_col_names) + len(feature_names)

	# Collect test & train
	test_nrows = features.data[feature_names[0]][test_inds].size
	test_data = np.zeros((test_nrows, ncols), dtype=float)
	train_nrows = features.data[feature_names[0]][~test_inds].size
	train_data = np.zeros((train_nrows, ncols), dtype=float)

	print("Got ", train_nrows, "+", test_nrows, " x ", ncols)

	# Fill matrices
	# Serial
	test_data[:, 0] = np.arange(test_nrows, dtype=float)
	train_data[:, 0] = np.arange(train_nrows, dtype=float)

	# Samples
	k=1
	for col in sample_col_names:
		test_data[:, k] = df_samples[col][test_inds]
		train_data[:, k] = df_samples[col][~test_inds]
		k = k + 1

	# Features
	for name in feature_names:
		test_data[:, k] = features.data[name][test_inds]
		train_data[:, k] = features.data[name][~test_inds]
		k = k + 1

	header = ["serial"] + sample_col_names + feature_names
	return Datasets(train=DataSet(train_data, header, treatment_name), test=DataSet(test_data, header, treatment_name))

def prep_data_set_from_features(features,treatment_name):

	fsamples = med.Samples()
	fsamples.import_from_sample_vec(features.samples)
	df_samples = fsamples.to_df()

	# Columns
	sample_col_names = list(df_samples.columns)
	feature_names = list(features.get_feature_names())
	ncols = 1 + len(sample_col_names) + len(feature_names)

	nrows = features.data[feature_names[0]].size
	data = np.zeros((nrows, ncols), dtype=float)
	print("Got ", nrows, " x ", ncols)

	data[:, 0] = np.arange(nrows, dtype=float)
	k = 1
	for col in sample_col_names:
		data[:, k] = df_samples[col]
		k = k + 1

	for name in feature_names:
		data[:, k] = features.data[name]
		k = k + 1

	header = ["serial"] + sample_col_names + feature_names
	return DataSet(data, header, treatment_name)

def prep_data_from_model(model_file, rep_file, samples_file, treatment_name):
	model = med.Model()
	samples = med.Samples()
	
	print("Reading Model")
	model.read_from_file(model_file)
	signalNamesSet = model.get_required_signal_names()
	
	print("Reading Samples")
	samples.read_from_file(samples_file)
	ids = samples.get_ids()
	
	print("Reading Repository")
	rep = med.PidRepository()
	rep.read_all(rep_file, ids, signalNamesSet)
	
	print("Get Matrix via apply:")
	model.apply(rep, samples)
		
	return prep_data_set_from_features(model.features,treatment_name)
